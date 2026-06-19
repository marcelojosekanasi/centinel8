from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core import crud, schemas
from app.core.security import get_current_user, get_current_admin
from app.core.models import Usuario
from app.ml.model import predictor

router = APIRouter()

@router.post("/predict", response_model=schemas.PrediccionResponse)
def get_prediction(
    req: schemas.PrediccionRequest,
    
    db: Session = Depends(get_db)
):
    """Estimar el nivel de riesgo de un incidente dada una coordenada, hora, día y categoría."""
    riesgo = predictor.predict_risk(
        latitud=req.latitud,
        longitud=req.longitud,
        hora=req.hora,
        dia_semana=req.dia_semana,
        categoria_id=req.categoria_id
    )
    
    # Obtener métricas actuales del modelo
    metrics = predictor.metrics
    acc = metrics.get("accuracy")
    prec = metrics.get("precision")
    rec = metrics.get("recall")
    f1 = metrics.get("f1_score")
    
    # Persistir la predicción solicitada en la BD para auditoría/estadística
    db_pred = crud.create_prediccion(
        db,
        latitud=req.latitud,
        longitud=req.longitud,
        hora=req.hora,
        dia_semana=req.dia_semana,
        categoria_id=req.categoria_id,
        riesgo=riesgo,
        acc=acc,
        prec=prec,
        rec=rec,
        f1=f1
    )
    
    return db_pred

@router.post("/train", response_model=schemas.TrainMetricsResponse)
def train_model(
    current_admin: Usuario = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    """Forzar el reentrenamiento del modelo de IA (Solo Administrador)."""
    try:
        metrics = predictor.train_model(db)
        crud.log_audit(
            db, 
            usuario_id=current_admin.id, 
            accion="ENTRENAMIENTO_MODELO_IA", 
            tabla="predicciones"
        )
        return metrics
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al entrenar el modelo de IA: {str(e)}"
        )

@router.get("/metrics", response_model=schemas.TrainMetricsResponse)
def get_model_metrics(
    current_user: Usuario = Depends(get_current_user)
):
    """Obtener las métricas de evaluación del modelo entrenado actualmente."""
    if not predictor.metrics:
        # Si no hay métricas cargadas, devolver métricas vacías iniciales
        return {
            "accuracy": 0.0,
            "precision": 0.0,
            "recall": 0.0,
            "f1_score": 0.0,
            "timestamp": "Modelo no entrenado"
        }
    return predictor.metrics
