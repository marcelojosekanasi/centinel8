import io
import csv
import pandas as pd
from datetime import datetime
from typing import List
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from app.core.models import Incidente

def build_incident_data_list(incidents: List[Incidente]) -> List[dict]:
    """Convierte una lista de incidentes SQLAlchemy a una lista de diccionarios para reportes."""
    data = []
    for inc in incidents:
        data.append({
            "ID": inc.id,
            "Fecha": inc.fecha_reporte.strftime("%Y-%m-%d %H:%M:%S") if inc.fecha_reporte else "",
            "Vecino": f"{inc.usuario.nombre} {inc.usuario.apellido}" if inc.usuario else "Anónimo",
            "Categoría": inc.categoria.nombre if inc.categoria else "Sin categoría",
            "Descripción": inc.descripcion,
            "Dirección": inc.direccion,
            "Coordenadas": f"{inc.latitud}, {inc.longitud}",
            "Riesgo": inc.nivel_riesgo,
            "Estado": inc.estado
        })
    return data

def generate_csv_report(incidents: List[Incidente]) -> io.BytesIO:
    """Genera un reporte CSV en memoria."""
    data_list = build_incident_data_list(incidents)
    output = io.StringIO()
    
    if data_list:
        writer = csv.DictWriter(output, fieldnames=data_list[0].keys())
        writer.writeheader()
        writer.writerows(data_list)
    else:
        output.write("No hay incidentes reportados en el rango seleccionado.")
        
    buf = io.BytesIO()
    buf.write(output.getvalue().encode("utf-8"))
    buf.seek(0)
    return buf

def generate_excel_report(incidents: List[Incidente]) -> io.BytesIO:
    """Genera un reporte Excel en memoria usando Pandas y Openpyxl."""
    data_list = build_incident_data_list(incidents)
    output = io.BytesIO()
    
    if data_list:
        df = pd.DataFrame(data_list)
    else:
        df = pd.DataFrame(columns=["ID", "Fecha", "Vecino", "Categoría", "Descripción", "Dirección", "Coordenadas", "Riesgo", "Estado"])
        
    with pd.ExcelWriter(output, engine="openpyxl") as writer:
        df.to_excel(writer, index=False, sheet_name="Incidentes")
        
    output.seek(0)
    return output

def generate_pdf_report(incidents: List[Incidente], filters_summary: str = "") -> io.BytesIO:
    """Genera un documento PDF formal y estilizado en memoria usando ReportLab."""
    output = io.BytesIO()
    doc = SimpleDocTemplate(
        output,
        pagesize=letter,
        rightMargin=36,
        leftMargin=36,
        topMargin=36,
        bottomMargin=36
    )
    
    styles = getSampleStyleSheet()
    
    # Crear estilos personalizados
    title_style = ParagraphStyle(
        name="TitleStyle",
        parent=styles["Heading1"],
        fontName="Helvetica-Bold",
        fontSize=18,
        textColor=colors.HexColor("#0D47A1"), # Azul de seguridad
        spaceAfter=10
    )
    
    meta_style = ParagraphStyle(
        name="MetaStyle",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=9,
        textColor=colors.HexColor("#555555"),
        spaceAfter=15
    )
    
    body_cell_style = ParagraphStyle(
        name="BodyCellStyle",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=8,
        leading=10
    )
    
    header_cell_style = ParagraphStyle(
        name="HeaderCellStyle",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=9,
        textColor=colors.white
    )

    story = []
    
    # Encabezado
    story.append(Paragraph("Centinel8 - Reporte de Incidentes Vecinales", title_style))
    fecha_generacion = datetime.now().strftime("%d/%m/%Y %H:%M:%S")
    story.append(Paragraph(
        f"Generado el: {fecha_generacion} | Subalcaldía del Distrito 8 de El Alto<br/>"
        f"Filtros aplicados: {filters_summary if filters_summary else 'Ninguno'}", 
        meta_style
    ))
    story.append(Spacer(1, 10))
    
    # Tabla de datos
    # Columnas: ID, Fecha, Categoría, Descripción (truncada), Dirección, Riesgo, Estado
    table_data = [[
        Paragraph("ID", header_cell_style),
        Paragraph("Fecha", header_cell_style),
        Paragraph("Categoría", header_cell_style),
        Paragraph("Descripción", header_cell_style),
        Paragraph("Dirección", header_cell_style),
        Paragraph("Riesgo", header_cell_style),
        Paragraph("Estado", header_cell_style)
    ]]
    
    for inc in incidents:
        # Truncar descripción larga para la vista de tabla
        desc_trunc = inc.descripcion[:60] + "..." if len(inc.descripcion) > 60 else inc.descripcion
        dir_trunc = inc.direccion[:40] + "..." if len(inc.direccion) > 40 else inc.direccion
        
        # Color del riesgo
        riesgo_col = "#2E7D32"  # Verde
        if inc.nivel_riesgo == "Alto":
            riesgo_col = "#C62828"  # Rojo
        elif inc.nivel_riesgo == "Medio":
            riesgo_col = "#F9A825"  # Amarillo oscuro
            
        riesgo_p = Paragraph(f"<font color='{riesgo_col}'><b>{inc.nivel_riesgo}</b></font>", body_cell_style)
        
        # Color del estado
        estado_col = "#1565C0"
        if inc.estado == "Atendido":
            estado_col = "#2E7D32"
        elif inc.estado == "Cerrado":
            estado_col = "#37474F"
            
        estado_p = Paragraph(f"<font color='{estado_col}'><b>{inc.estado}</b></font>", body_cell_style)

        table_data.append([
            Paragraph(str(inc.id), body_cell_style),
            Paragraph(inc.fecha_reporte.strftime("%d/%m/%Y %H:%M") if inc.fecha_reporte else "", body_cell_style),
            Paragraph(inc.categoria.nombre if inc.categoria else "Sin cat.", body_cell_style),
            Paragraph(desc_trunc, body_cell_style),
            Paragraph(dir_trunc, body_cell_style),
            riesgo_p,
            estado_p
        ])
        
    # Ancho de columnas adaptado al tamaño carta horizontal o vertical
    # Ancho total disponible = 612 - 72 = 540 puntos
    col_widths = [30, 80, 70, 150, 110, 50, 50]
    
    t = Table(table_data, colWidths=col_widths, repeatRows=1)
    t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#0D47A1")),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('TEXTCOLOR', (0,0), (-1,0), colors.white),
        ('BOTTOMPADDING', (0,0), (-1,0), 6),
        ('TOPPADDING', (0,0), (-1,0), 6),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#CCCCCC")),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor("#F5F5F5")]),
        ('BOTTOMPADDING', (0,1), (-1,-1), 5),
        ('TOPPADDING', (0,1), (-1,-1), 5),
    ]))
    
    story.append(t)
    
    doc.build(story)
    output.seek(0)
    return output
