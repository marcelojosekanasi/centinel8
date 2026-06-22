from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List, Optional
from datetime import datetime
import os
import uuid
import math

def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return 2 * R * math.asin(math.sqrt(a))


from app.core.database import get_db
from app.core import crud, schemas
from app.core.security import get_current_user, get_current_admin
from app.core.models import Usuario, Incidente, Categoria, Alerta, Notificacion
from app.ml.model import predictor
from app.utils.fcm import send_push_notification

router = APIRouter()

UPLOAD_DIR = "static/uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@router.get("/", response_model=List[schemas.IncidenteResponse])
def read_incidents(
    skip: int = 0,
    limit: int = 100,
    personal: bool = Query(default=False, description="Filtrar solo incidentes reportados por mÃ­"),
    categoria_id: Optional[int] = None,
    estado: Optional[str] = None,
    fecha_inicio: Optional[datetime] = None,
    fecha_fin: Optional[datetime] = None,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Obtener listado de incidentes. Admite filtros temporales, de estado y por categorÃ­a."""
    usuario_id = current_user.id if personal else None
    return crud.get_incidents(
        db, 
        skip=skip, 
        limit=limit, 
        usuario_id=usuario_id, 
        categoria_id=categoria_id, 
        estado=estado, 
        fecha_inicio=fecha_inicio, 
        fecha_fin=fecha_fin
    )

@router.post("/", response_model=schemas.IncidenteResponse, status_code=status.HTTP_201_CREATED)
def create_incident(
    categoria_id: int = Form(...),
    descripcion: str = Form(...),
    latitud: float = Form(...),
    longitud: float = Form(...),
    direccion: str = Form(...),
    file: Optional[UploadFile] = File(None),
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Permite a los vecinos registrar un nuevo incidente, adjuntar foto opcional y predecir el riesgo automÃ¡ticamente."""
    imagen_url = None
    if file:
        file_ext = os.path.splitext(file.filename)[1]
        unique_filename = f"{uuid.uuid4()}{file_ext}"
        filepath = os.path.join(UPLOAD_DIR, unique_filename)
        with open(filepath, "wb") as f:
            f.write(file.file.read())
        imagen_url = f"/static/uploads/{unique_filename}"
        
    incident_data = schemas.IncidenteCreate(
        categoria_id=categoria_id,
        descripcion=descripcion,
        latitud=latitud,
        longitud=longitud,
        direccion=direccion,
        imagen=imagen_url
    )
    
    # 1. Crear incidente
    db_incident = crud.create_incident(db, incident=incident_data, usuario_id=current_user.id)
    
    # 2. Utilizar el modelo de IA para predecir el nivel de riesgo del incidente
    fecha_actual = db_incident.fecha_reporte or datetime.now()
    hora = fecha_actual.hour
    dia_semana = fecha_actual.weekday()
    
    riesgo_predicho = predictor.predict_risk(
        latitud=latitud,
        longitud=longitud,
        hora=hora,
        dia_semana=dia_semana,
        categoria_id=categoria_id
    )
    
    # Guardar predicciÃ³n en la base de datos
    db_incident.nivel_riesgo = riesgo_predicho
    db.add(db_incident)
    db.commit()
    db.refresh(db_incident)
    
    # Registrar auditorÃ­a
    crud.log_audit(db, usuario_id=current_user.id, accion="CREAR_INCIDENTE", tabla="incidentes", registro_id=db_incident.id)
    
    # 3. Alertas inteligentes: Si es riesgo ALTO, gatillar alerta push a vecinos cercanos
    if riesgo_predicho == "Alto":
        trigger_neighborhood_alert(db, db_incident)
        
    return db_incident

@router.post("/panic", response_model=schemas.IncidenteResponse, status_code=status.HTTP_201_CREATED)
def trigger_panic(
    latitud: float = Form(...),
    longitud: float = Form(...),
    direccion: str = Form(...),
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    BotÃ³n de PÃ¡nico: Crea un incidente prioritario instantÃ¡neo (Riesgo ALTO).
    Notifica a vecinos aledaÃ±os en un radio de 500m y genera alerta administrativa.
    DiseÃ±ado para responder en menos de 2 segundos.
    """
    # CategorÃ­a 8 = Otro (emergencia prioritaria)
    incident_data = schemas.IncidenteCreate(
        categoria_id=8,
        descripcion=f"BOTÃ“N DE PÃNICO ACTIVADO por el ciudadano {current_user.nombre} {current_user.apellido}",
        latitud=latitud,
        longitud=longitud,
        direccion=direccion,
        imagen=None
    )
    
    # Registrar incidente de emergencia
    db_incident = crud.create_incident(db, incident=incident_data, usuario_id=current_user.id)
    db_incident.nivel_riesgo = "Alto"
    db_incident.estado = "Pendiente"
    db.add(db_incident)
    db.commit()
    db.refresh(db_incident)
    
    crud.log_audit(db, usuario_id=current_user.id, accion="BOTON_PANICO_ACTIVADO", tabla="incidentes", registro_id=db_incident.id)
    
    # Enviar alerta inmediata
    trigger_neighborhood_alert(db, db_incident, es_panico=True)
    
    return db_incident

@router.get("/{incident_id}", response_model=schemas.IncidenteResponse)
def read_incident(incident_id: int, current_user: Usuario = Depends(get_current_user), db: Session = Depends(get_db)):
    """Consultar los detalles de un incidente especÃ­fico."""
    inc = crud.get_incident(db, incident_id=incident_id)
    if not inc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Incidente no encontrado.")
    return inc

@router.put("/{incident_id}", response_model=schemas.IncidenteResponse)
def update_incident_status(
    incident_id: int,
    incident_upd: schemas.IncidenteUpdate,
    current_admin: Usuario = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    """Permite al administrador cambiar el estado (En proceso, Atendido, Cerrado) o ajustar el nivel de riesgo."""
    db_incident = crud.get_incident(db, incident_id=incident_id)
    if not db_incident:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Incidente no encontrado.")
        
    updated = crud.update_incident(db, db_incident=db_incident, incident_in=incident_upd, usuario_cambio_id=current_admin.id)
    return updated

def trigger_neighborhood_alert(db: Session, incident: Incidente, es_panico: bool = False):
    """
    Busca vecinos en un radio aproximado de 500m (0.0045 grados en PostGIS) y
    les despacha una alerta push / notificaciÃ³n instantÃ¡nea.
    """
    # 1. Crear registro global de la alerta
    titulo = "âš ï¸ EMERGENCIA VECINAL - BOTÃ“N DE PÃNICO" if es_panico else "âš ï¸ ALERTA DE SEGURIDAD - RIESGO ALTO"
    mensaje = f"Se reporta un incidente crÃ­tico ({incident.categoria.nombre}) en: {incident.direccion}. Tome precauciones."
    
    alerta = crud.create_alerta(
        db, 
        incidente_id=incident.id, 
        titulo=titulo, 
        mensaje=mensaje, 
        tipo="Panico" if es_panico else "Push"
    )
    
    # 2. Buscar vecinos cercanos con PostGIS (ST_DWithin en radio de 500m -> 0.0045 grados)
    # Si no hay incidentes previos geolocalizados de usuarios, caemos en enviar la alerta a todos los vecinos
    # activos del Distrito 8 para asegurar difusiÃ³n preventiva.
    # Filtrar vecinos dentro de un radio de 500m usando su ubicacion de domicilio registrada
    RADIO_KM = 0.5
    todos_vecinos = db.query(Usuario).filter(Usuario.rol_id == 1, Usuario.estado == "Activo").all()
    vecinos = []
    for v in todos_vecinos:
        if v.latitud is None or v.longitud is None:
            continue
        dist_km = haversine_km(incident.latitud, incident.longitud, v.latitud, v.longitud)
        if dist_km <= RADIO_KM:
            vecinos.append(v)
    vecinos_ids = [v.id for v in vecinos]
    if vecinos_ids:
        # Registrar notificaciones individuales
        crud.create_notificaciones_for_users(db, alerta_id=alerta.id, user_ids=vecinos_ids)
        # Despachar notificaciones push mÃ³viles
        send_push_notification(
            db,
            user_ids=vecinos_ids,
            title=titulo,
            body=mensaje,
            data={"incident_id": incident.id, "lat": incident.latitud, "lng": incident.longitud, "tipo": "panico" if es_panico else "riesgo_alto"}
        )
        
    # Enviar notificaciÃ³n especial a los administradores
    admins = db.query(Usuario).filter(Usuario.rol_id == 2, Usuario.estado == "Activo").all()
    admins_ids = [a.id for a in admins]
    if admins_ids:
        send_push_notification(
            db,
            user_ids=admins_ids,
            title=f"ðŸš¨ ADMIN - NUEVA ALERTA DE INCIDENTE",
            body=f"Alerta de pÃ¡nico o riesgo alto registrada por usuario ID {incident.usuario_id}.",
            data={"incident_id": incident.id}
        )
