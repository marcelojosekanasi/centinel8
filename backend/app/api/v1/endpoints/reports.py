from fastapi import APIRouter, Depends, HTTPException, status, Query, Response
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from datetime import datetime
from typing import Optional

from app.core.database import get_db
from app.core import crud
from app.core.security import get_current_admin
from app.core.models import Usuario
from app.utils.reports_generator import generate_pdf_report, generate_excel_report, generate_csv_report

router = APIRouter()

@router.get("/export", status_code=status.HTTP_200_OK)
def export_reports(
    formato: str = Query(..., description="Formato del archivo: pdf, excel o csv"),
    categoria_id: Optional[int] = Query(None, description="Filtrar por categoría"),
    estado: Optional[str] = Query(None, description="Filtrar por estado"),
    fecha_inicio: Optional[datetime] = Query(None, description="Fecha de inicio (ISO format)"),
    fecha_fin: Optional[datetime] = Query(None, description="Fecha de fin (ISO format)"),
    current_admin: Usuario = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    """Generar y descargar reportes consolidados en formato PDF, Excel o CSV (Solo Administrador)."""
    # 1. Obtener incidentes según filtros
    # Nota: pasamos limit=10000 para descargar todos los registros coincidentes en reportes
    incidents = crud.get_incidents(
        db, 
        skip=0, 
        limit=10000, 
        categoria_id=categoria_id, 
        estado=estado, 
        fecha_inicio=fecha_inicio, 
        fecha_fin=fecha_fin
    )
    
    # 2. Resumen de filtros aplicados
    filtros_resumen = []
    if categoria_id:
        # Obtener el nombre de la categoria
        from app.core.models import Categoria
        cat = db.query(Categoria).filter(Categoria.id == categoria_id).first()
        if cat:
            filtros_resumen.append(f"Categoría: {cat.nombre}")
    if estado:
        filtros_resumen.append(f"Estado: {estado}")
    if fecha_inicio:
        filtros_resumen.append(f"Desde: {fecha_inicio.strftime('%Y-%m-%d')}")
    if fecha_fin:
        filtros_resumen.append(f"Hasta: {fecha_fin.strftime('%Y-%m-%d')}")
        
    filters_summary = " | ".join(filtros_resumen) if filtros_resumen else "Todos los incidentes"

    # Registrar auditoría de exportación
    crud.log_audit(
        db, 
        usuario_id=current_admin.id, 
        accion=f"EXPORTAR_REPORTE ({formato.upper()})", 
        tabla="incidentes"
    )

    # 3. Generar archivo correspondiente
    formato = formato.lower()
    timestamp = datetime.now().strftime("%Y%md_%H%M%S")
    
    if formato == "pdf":
        pdf_file = generate_pdf_report(incidents, filters_summary=filters_summary)
        return StreamingResponse(
            pdf_file,
            media_type="application/pdf",
            headers={"Content-Disposition": f"attachment; filename=centinel8_reporte_{timestamp}.pdf"}
        )
        
    elif formato == "excel":
        excel_file = generate_excel_report(incidents)
        return StreamingResponse(
            excel_file,
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            headers={"Content-Disposition": f"attachment; filename=centinel8_reporte_{timestamp}.xlsx"}
        )
        
    elif formato == "csv":
        csv_file = generate_csv_report(incidents)
        return StreamingResponse(
            csv_file,
            media_type="text/csv",
            headers={"Content-Disposition": f"attachment; filename=centinel8_reporte_{timestamp}.csv"}
        )
        
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Formato de reporte inválido. Formatos válidos: pdf, excel, csv"
        )
