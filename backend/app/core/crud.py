from sqlalchemy.orm import Session
from sqlalchemy import func, and_, desc
from datetime import datetime, timedelta
from typing import List, Optional
from app.core.models import (
    Usuario, Rol, Categoria, Incidente, Prediccion, 
    Alerta, Notificacion, HistorialIncidente, Auditoria, TokenRecuperacion
)
from app.core.schemas import UsuarioCreate, UsuarioUpdate, IncidenteCreate, IncidenteUpdate
from app.core.security import get_password_hash

# --- CRUD de Roles ---
def get_roles(db: Session) -> List[Rol]:
    return db.query(Rol).all()

# --- CRUD de Categorías ---
def get_categorias(db: Session) -> List[Categoria]:
    return db.query(Categoria).all()

def create_categoria(db: Session, nombre: str, descripcion: Optional[str] = None) -> Categoria:
    db_cat = Categoria(nombre=nombre, descripcion=descripcion)
    db.add(db_cat)
    db.commit()
    db.refresh(db_cat)
    return db_cat

# --- CRUD de Usuarios ---
def get_user(db: Session, user_id: int) -> Optional[Usuario]:
    return db.query(Usuario).filter(Usuario.id == user_id).first()

def get_user_by_email(db: Session, email: str) -> Optional[Usuario]:
    return db.query(Usuario).filter(func.lower(Usuario.correo) == email.lower()).first()

def get_user_by_ci(db: Session, ci: str) -> Optional[Usuario]:
    return db.query(Usuario).filter(Usuario.ci == ci).first()

def get_users(db: Session, skip: int = 0, limit: int = 100) -> List[Usuario]:
    return db.query(Usuario).offset(skip).limit(limit).all()

def create_user(db: Session, user: UsuarioCreate) -> Usuario:
    hashed_password = get_password_hash(user.contrasena)
    db_user = Usuario(
        nombre=user.nombre,
        apellido=user.apellido,
        ci=user.ci,
        celular=user.celular,
        correo=user.correo,
        contrasena=hashed_password,
        rol_id=user.rol_id,
        estado="Activo"
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

def update_user(db: Session, db_user: Usuario, user_in: UsuarioUpdate) -> Usuario:
    update_data = user_in.model_dump(exclude_unset=True)
    if "contrasena" in update_data and update_data["contrasena"]:
        update_data["contrasena"] = get_password_hash(update_data["contrasena"])
    
    for field in update_data:
        setattr(db_user, field, update_data[field])
        
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

# --- CRUD de Incidentes ---
def get_incident(db: Session, incident_id: int) -> Optional[Incidente]:
    return db.query(Incidente).filter(Incidente.id == incident_id).first()

def get_incidents(
    db: Session, 
    skip: int = 0, 
    limit: int = 100, 
    usuario_id: Optional[int] = None,
    categoria_id: Optional[int] = None,
    estado: Optional[str] = None,
    fecha_inicio: Optional[datetime] = None,
    fecha_fin: Optional[datetime] = None
) -> List[Incidente]:
    query = db.query(Incidente)
    if usuario_id is not None:
        query = query.filter(Incidente.usuario_id == usuario_id)
    if categoria_id is not None:
        query = query.filter(Incidente.categoria_id == categoria_id)
    if estado is not None:
        query = query.filter(Incidente.estado == estado)
    if fecha_inicio is not None:
        query = query.filter(Incidente.fecha_reporte >= fecha_inicio)
    if fecha_fin is not None:
        query = query.filter(Incidente.fecha_reporte <= fecha_fin)
        
    return query.order_by(desc(Incidente.fecha_reporte)).offset(skip).limit(limit).all()

def create_incident(db: Session, incident: IncidenteCreate, usuario_id: int) -> Incidente:
    # Crear la ubicación en formato PostGIS usando ST_SetSRID y ST_MakePoint
    geom = func.ST_SetSRID(func.ST_MakePoint(incident.longitud, incident.latitud), 4326)
    
    db_incident = Incidente(
        usuario_id=usuario_id,
        categoria_id=incident.categoria_id,
        descripcion=incident.descripcion,
        latitud=incident.latitud,
        longitud=incident.longitud,
        geom=geom,
        direccion=incident.direccion,
        imagen=incident.imagen,
        estado="Pendiente",
        nivel_riesgo="Bajo"
    )
    db.add(db_incident)
    db.commit()
    db.refresh(db_incident)
    return db_incident

def update_incident(
    db: Session, 
    db_incident: Incidente, 
    incident_in: IncidenteUpdate,
    usuario_cambio_id: int
) -> Incidente:
    estado_anterior = db_incident.estado
    
    update_data = incident_in.model_dump(exclude_unset=True)
    for field in update_data:
        setattr(db_incident, field, update_data[field])
        
    db.add(db_incident)
    
    # Registrar en el historial si cambió el estado
    if "estado" in update_data and update_data["estado"] != estado_anterior:
        db_historial = HistorialIncidente(
            incidente_id=db_incident.id,
            estado_anterior=estado_anterior,
            estado_nuevo=db_incident.estado,
            usuario_cambio_id=usuario_cambio_id,
            comentario=f"Estado actualizado por el administrador."
        )
        db.add(db_historial)
        
    db.commit()
    db.refresh(db_incident)
    return db_incident

# --- CRUD de Alertas y Notificaciones ---
def create_alerta(db: Session, incidente_id: Optional[int], titulo: str, mensaje: str, tipo: str = "Push") -> Alerta:
    db_alerta = Alerta(
        incidente_id=incidente_id,
        titulo=titulo,
        mensaje=mensaje,
        tipo=tipo
    )
    db.add(db_alerta)
    db.commit()
    db.refresh(db_alerta)
    return db_alerta

def create_notificaciones_for_users(db: Session, alerta_id: int, user_ids: List[int]) -> List[Notificacion]:
    notifs = []
    for uid in user_ids:
        db_notif = Notificacion(usuario_id=uid, alerta_id=alerta_id, leida=False)
        db.add(db_notif)
        notifs.append(db_notif)
    db.commit()
    return notifs

def get_user_notifications(db: Session, usuario_id: int, limit: int = 50) -> List[Notificacion]:
    return db.query(Notificacion).filter(
        Notificacion.usuario_id == usuario_id
    ).order_by(desc(Notificacion.fecha_recepcion)).limit(limit).all()

def mark_notification_read(db: Session, notification_id: int, usuario_id: int) -> Optional[Notificacion]:
    db_notif = db.query(Notificacion).filter(
        Notificacion.id == notification_id,
        Notificacion.usuario_id == usuario_id
    ).first()
    if db_notif:
        db_notif.leida = True
        db.add(db_notif)
        db.commit()
        db.refresh(db_notif)
    return db_notif

# --- CRUD de Predicciones ---
def create_prediccion(
    db: Session, 
    latitud: float, 
    longitud: float, 
    hora: int, 
    dia_semana: int, 
    categoria_id: int, 
    riesgo: str,
    acc: Optional[float] = None,
    prec: Optional[float] = None,
    rec: Optional[float] = None,
    f1: Optional[float] = None
) -> Prediccion:
    db_pred = Prediccion(
        latitud=latitud,
        longitud=longitud,
        hora=hora,
        dia_semana=dia_semana,
        categoria_id=categoria_id,
        nivel_riesgo_predicho=riesgo,
        accuracy=acc,
        precision_score=prec,
        recall=rec,
        f1_score=f1
    )
    db.add(db_pred)
    db.commit()
    db.refresh(db_pred)
    return db_pred

# --- Registro de Auditoría ---
def log_audit(
    db: Session, 
    usuario_id: Optional[int], 
    accion: str, 
    tabla: str, 
    registro_id: Optional[int] = None,
    ip: Optional[str] = None
) -> Auditoria:
    db_audit = Auditoria(
        usuario_id=usuario_id,
        accion=accion,
        tabla_afectada=tabla,
        registro_id=registro_id,
        ip_origen=ip
    )
    db.add(db_audit)
    db.commit()
    return db_audit

# --- Tokens de Recuperación ---
def create_recovery_token(db: Session, usuario_id: int, token: str) -> TokenRecuperacion:
    # Expiración en 2 horas
    expiracion = datetime.now() + timedelta(hours=2)
    db_token = TokenRecuperacion(
        usuario_id=usuario_id,
        token=token,
        expiracion=expiracion,
        utilizado=False
    )
    db.add(db_token)
    db.commit()
    db.refresh(db_token)
    return db_token

def get_valid_recovery_token(db: Session, token: str) -> Optional[TokenRecuperacion]:
    return db.query(TokenRecuperacion).filter(
        TokenRecuperacion.token == token,
        TokenRecuperacion.expiracion > datetime.now(),
        TokenRecuperacion.utilizado == False
    ).first()
