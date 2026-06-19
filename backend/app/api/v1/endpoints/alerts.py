from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.core.database import get_db
from app.core import crud, schemas
from app.core.security import get_current_user
from app.core.models import Usuario

router = APIRouter()

@router.get("/notifications", response_model=List[schemas.NotificacionResponse])
def get_my_notifications(
    limit: int = 50,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Obtener el listado de notificaciones personales enviadas al vecino."""
    return crud.get_user_notifications(db, usuario_id=current_user.id, limit=limit)

@router.put("/notifications/{notification_id}/read", response_model=schemas.NotificacionResponse)
def mark_notification_as_read(
    notification_id: int,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Marcar una notificación específica como leída por el vecino."""
    notif = crud.mark_notification_read(db, notification_id=notification_id, usuario_id=current_user.id)
    if not notif:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notificación no encontrada o no pertenece a su usuario."
        )
    return notif
