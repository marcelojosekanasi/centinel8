import uuid
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core import crud, schemas
from app.core.security import verify_password, create_access_token, get_current_user
from app.core.models import TokenRecuperacion
from app.utils.email import send_recovery_email

router = APIRouter()

@router.post("/register", response_model=schemas.UsuarioResponse, status_code=status.HTTP_201_CREATED)
def register(user_in: schemas.UsuarioCreate, db: Session = Depends(get_db)):
    """Registrar un nuevo vecino en la plataforma."""
    # Verificar si el correo ya existe
    db_user = crud.get_user_by_email(db, email=user_in.correo)
    if db_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El correo electrónico ya se encuentra registrado."
        )
    # Verificar si el CI ya existe
    db_user_ci = crud.get_user_by_ci(db, ci=user_in.ci)
    if db_user_ci:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La Cédula de Identidad (CI) ya se encuentra registrada."
        )
    # Forzar rol Vecino (1) si no es admin creador
    user_in.rol_id = 1
    new_user = crud.create_user(db, user=user_in)
    
    # Registrar auditoría
    crud.log_audit(
        db, 
        usuario_id=new_user.id, 
        accion="REGISTRO_USUARIO", 
        tabla="usuarios", 
        registro_id=new_user.id
    )
    return new_user

@router.post("/login", response_model=schemas.TokenResponse)
def login(login_data: schemas.LoginRequest, request: Request, db: Session = Depends(get_db)):
    """Iniciar sesión con correo y contraseña, devuelve token JWT y datos de usuario."""
    user = crud.get_user_by_email(db, email=login_data.correo)
    if not user or not verify_password(login_data.contrasena, user.contrasena):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Correo o contraseña incorrectos."
        )
    
    if user.estado != "Activo":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Su cuenta está inactiva. Contacte a un administrador."
        )
        
    access_token = create_access_token(subject=user.id)
    
    # Registrar auditoría de ingreso
    ip = request.client.host if request.client else None
    crud.log_audit(
        db, 
        usuario_id=user.id, 
        accion="LOGIN", 
        tabla="usuarios", 
        registro_id=user.id, 
        ip=ip
    )
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "usuario": user
    }

@router.post("/logout", status_code=status.HTTP_200_OK)
def logout(current_user=Depends(get_current_user), db: Session = Depends(get_db)):
    """Cerrar sesión e invalidar tokens localmente (audita el evento)."""
    crud.log_audit(
        db, 
        usuario_id=current_user.id, 
        accion="LOGOUT", 
        tabla="usuarios", 
        registro_id=current_user.id
    )
    return {"message": "Sesión cerrada correctamente."}

@router.post("/recover-password", status_code=status.HTTP_200_OK)
def recover_password(recover_data: schemas.RecuperarContrasenaRequest, db: Session = Depends(get_db)):
    """Genera un token de recuperación y simula el envío al correo del vecino."""
    user = crud.get_user_by_email(db, email=recover_data.correo)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="El correo no está registrado en el sistema."
        )
        
    token = str(uuid.uuid4())
    crud.create_recovery_token(db, usuario_id=user.id, token=token)
    
    # Enviar correo real
    send_recovery_email(email_to=user.correo, token=token, nombre=user.nombre)

    # Simulación de correo
    print(f"--- [MOCK CORREO RECUPERACION] ---")
    print(f"Para: {user.correo}")
    print(f"Token de restablecimiento: {token}")
    print(f"Enlace simulado: http://localhost:8000/api/v1/auth/reset-password?token={token}")
    print(f"----------------------------------")
    
    crud.log_audit(
        db, 
        usuario_id=user.id, 
        accion="SOLICITUD_RECUPERACION", 
        tabla="tokens_recuperacion"
    )
    return {"message": "Si el correo existe, se enviará un enlace de recuperación."}

@router.post("/reset-password", status_code=status.HTTP_200_OK)
def reset_password(reset_data: schemas.RestablecerContrasenaRequest, db: Session = Depends(get_db)):
    """Valida el token de recuperación y actualiza la contraseña del usuario."""
    db_token = crud.get_valid_recovery_token(db, token=reset_data.token)
    if not db_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Token inválido o expirado."
        )
        
    user = db_token.usuario
    user_update = schemas.UsuarioUpdate(contrasena=reset_data.nueva_contrasena)
    crud.update_user(db, db_user=user, user_in=user_update)
    
    # Marcar token como utilizado
    db_token.utilizado = True
    db.add(db_token)
    db.commit()
    
    crud.log_audit(
        db, 
        usuario_id=user.id, 
        accion="RESTABLECER_CONTRASENA", 
        tabla="usuarios", 
        registro_id=user.id
    )
    return {"message": "Contraseña restablecida correctamente."}

@router.get("/verify-email", status_code=status.HTTP_200_OK)
def verify_email(token: str, db: Session = Depends(get_db)):
    """Verifica la dirección de correo electrónico del usuario (Simulación)."""
    # Para efectos prácticos de este entregable, la verificación aprueba al usuario inmediatamente
    return {"message": "Correo electrónico verificado con éxito."}
