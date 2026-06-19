from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime, time
from typing import Dict, List

from app.core.database import get_db
from app.core import crud, schemas
from app.core.security import get_current_admin
from app.core.models import Usuario, Incidente, Categoria, Prediccion

router = APIRouter()

@router.get("/stats", response_model=schemas.DashboardStats, status_code=status.HTTP_200_OK)
def get_dashboard_stats(
    current_admin: Usuario = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    """Obtener métricas, agregados e incidentes recientes para el panel administrativo (Solo Administrador)."""
    # 1. Total de usuarios
    total_usuarios = db.query(Usuario).count()
    
    # 2. Total de incidentes
    total_incidentes = db.query(Incidente).count()
    
    # 3. Incidentes registrados el día de hoy
    inicio_hoy = datetime.combine(datetime.today(), time.min)
    fin_hoy = datetime.combine(datetime.today(), time.max)
    incidentes_hoy = db.query(Incidente).filter(
        Incidente.fecha_reporte >= inicio_hoy,
        Incidente.fecha_reporte <= fin_hoy
    ).count()
    
    # 4. Incidentes agrupados por categoría
    incidentes_cat_query = db.query(
        Categoria.nombre, func.count(Incidente.id)
    ).join(
        Incidente, Categoria.id == Incidente.categoria_id, isouter=True
    ).group_by(Categoria.nombre).all()
    
    incidentes_por_categoria = {nombre: count for nombre, count in incidentes_cat_query}
    
    # Asegurar que todas las categorías obligatorias aparezcan en la estadística
    categorias_globales = ["Robo", "Agresión", "Asalto", "Violencia", "Vandalismo", "Accidente", "Emergencia médica", "Otro"]
    for cat in categorias_globales:
        if cat not in incidentes_por_categoria:
            incidentes_por_categoria[cat] = 0
            
    # 5. Incidentes agrupados por estado
    incidentes_est_query = db.query(
        Incidente.estado, func.count(Incidente.id)
    ).group_by(Incidente.estado).all()
    
    incidentes_por_estado = {estado: count for estado, count in incidentes_est_query}
    estados_posibles = ["Pendiente", "En proceso", "Atendido", "Cerrado"]
    for est in estados_posibles:
        if est not in incidentes_por_estado:
            incidentes_por_estado[est] = 0
            
    # 6. Incidentes recientes (los últimos 5 reportados)
    recent_incidents = db.query(Incidente).order_by(
        Incidente.fecha_reporte.desc()
    ).limit(5).all()
    
    # 7. Total de predicciones realizadas por IA
    predicciones_totales = db.query(Prediccion).count()
    
    return {
        "total_usuarios": total_usuarios,
        "total_incidentes": total_incidentes,
        "incidentes_hoy": incidentes_hoy,
        "incidentes_por_categoria": incidentes_por_categoria,
        "incidentes_por_estado": incidentes_por_estado,
        "incidentes_recientes": recent_incidents,
        "predicciones_totales": predicciones_totales
    }
