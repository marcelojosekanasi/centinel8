from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.core.database import get_db
from app.core import crud, schemas
from app.core.security import get_current_user, get_current_admin, verify_password
from app.core.models import Usuario

router = APIRouter()

@router.get("/me", response_model=schemas.UsuarioResponse)
def read_user_me(current_user: Usuario = Depends(get_current_user)):
    """Obtener el perfil del usuario autenticado actual."""
    return current_user

@router.put("/me", response_model=schemas.UsuarioResponse)
def update_user_me(
    user_in: schemas.UsuarioUpdate,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Actualizar datos del perfil propio (Vecino/Administrador)."""
    # Si cambia el correo, verificar disponibilidad
    if user_in.correo and user_in.correo != current_user.correo:
        db_user = crud.get_user_by_email(db, email=user_in.correo)
        if db_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="El correo electrónico ya está en uso."
            )
            
    updated_user = crud.update_user(db, db_user=current_user, user_in=user_in)
    crud.log_audit(
        db, 
        usuario_id=current_user.id, 
        accion="ACTUALIZAR_PERFIL", 
        tabla="usuarios", 
        registro_id=current_user.id
    )
    return updated_user

@router.post("/change-password", status_code=status.HTTP_200_OK)
def change_password(
    pwd_data: schemas.CambiarContrasenaRequest,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Cambiar la contraseña desde la pantalla de perfil del vecino."""
    if not verify_password(pwd_data.contrasena_actual, current_user.contrasena):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La contraseña actual ingresada es incorrecta."
        )
        
    user_upd = schemas.UsuarioUpdate(contrasena=pwd_data.nueva_contrasena)
    crud.update_user(db, db_user=current_user, user_in=user_upd)
    
    crud.log_audit(
        db, 
        usuario_id=current_user.id, 
        accion="CAMBIO_CONTRASENA_PERFIL", 
        tabla="usuarios", 
        registro_id=current_user.id
    )
    return {"message": "Contraseña cambiada con éxito."}

@router.post("/me/device-token", status_code=status.HTTP_200_OK)
def register_device_token(
    device_data: schemas.DispositivoFCMCreate,
    current_user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Registrar o actualizar el token FCM de un dispositivo para notificaciones push."""
    from app.core.models import DispositivoFCM

    existing = db.query(DispositivoFCM).filter(
        DispositivoFCM.token == device_data.token
    ).first()

    if existing:
        existing.usuario_id = current_user.id
        existing.plataforma = device_data.plataforma
        existing.activo = True
        db.commit()
    else:
        nuevo_dispositivo = DispositivoFCM(
            usuario_id=current_user.id,
            token=device_data.token,
            plataforma=device_data.plataforma,
        )
        db.add(nuevo_dispositivo)
        db.commit()

    return {"message": "Token de dispositivo registrado correctamente."}

# --- RUTAS DE ADMINISTRADOR ---

@router.get("/", response_model=List[schemas.UsuarioResponse])
def read_users(
    skip: int = 0,
    limit: int = 100,
    current_admin: Usuario = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    """Listar todos los usuarios registrados (Solo Administrador)."""
    return crud.get_users(db, skip=skip, limit=limit)

@router.put("/{user_id}", response_model=schemas.UsuarioResponse)
def update_user_by_admin(
    user_id: int,
    user_in: schemas.UsuarioUpdate,
    current_admin: Usuario = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    """Modificar estado o detalles de cualquier usuario (Solo Administrador)."""
    db_user = crud.get_user(db, user_id=user_id)
    if not db_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado."
        )
        
    updated_user = crud.update_user(db, db_user=db_user, user_in=user_in)
    crud.log_audit(
        db, 
        usuario_id=current_admin.id, 
        accion=f"MODIFICAR_USUARIO_ADMIN (id: {user_id})", 
        tabla="usuarios", 
        registro_id=user_id
    )
    return updated_user


@router.delete("/{user_id}", status_code=status.HTTP_200_OK)
def delete_user_by_admin(
    user_id: int,
    current_admin: Usuario = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    """Bloquear (soft-delete) a un usuario. No se elimina de la BD para preservar integridad referencial (incidentes, alertas, etc)."""
    if user_id == current_admin.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No puede eliminar su propia cuenta de administrador."
        )
    db_user = crud.get_user(db, user_id=user_id)
    if not db_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado."
        )
    db_user.estado = "Eliminado"
    db.add(db_user)
    db.commit()
    crud.log_audit(
        db,
        usuario_id=current_admin.id,
        accion=f"ELIMINAR_USUARIO_ADMIN (id: {user_id})",
        tabla="usuarios",
        registro_id=user_id
    )
    return {"message": "Usuario eliminado (bloqueado) con éxito."}

