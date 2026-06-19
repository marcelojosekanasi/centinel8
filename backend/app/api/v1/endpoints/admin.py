from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.core.database import get_db
from app.core import crud, schemas
from app.core.security import get_current_admin
from app.core.models import Usuario, Categoria
router = APIRouter()

@router.get("/users", response_model=List[schemas.UsuarioResponse])
def list_users(current_admin: Usuario = Depends(get_current_admin), db: Session = Depends(get_db)):
    return crud.get_users(db, skip=0, limit=1000)

@router.put("/users/{user_id}", response_model=schemas.UsuarioResponse)
def update_user(user_id: int, user_in: schemas.UsuarioUpdate, current_admin: Usuario = Depends(get_current_admin), db: Session = Depends(get_db)):
    user = crud.get_user(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado.")
    updated = crud.update_user(db, db_user=user, user_in=user_in)
    crud.log_audit(db, usuario_id=current_admin.id, accion=f"ACTUALIZAR_USUARIO (id:{user_id})", tabla="usuarios", registro_id=user_id)
    return updated

@router.delete("/users/{user_id}", status_code=status.HTTP_200_OK)
def delete_user(user_id: int, current_admin: Usuario = Depends(get_current_admin), db: Session = Depends(get_db)):
    if user_id == current_admin.id:
        raise HTTPException(status_code=400, detail="No puedes eliminar tu propia cuenta.")
    user = crud.get_user(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado.")
    db.delete(user)
    db.commit()
    crud.log_audit(db, usuario_id=current_admin.id, accion=f"ELIMINAR_USUARIO (id:{user_id})", tabla="usuarios", registro_id=user_id)
    return {"message": "Usuario eliminado correctamente."}

@router.patch("/users/{user_id}/status", response_model=schemas.UsuarioResponse)
def toggle_user_status(user_id: int, current_admin: Usuario = Depends(get_current_admin), db: Session = Depends(get_db)):
    user = crud.get_user(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado.")
    new_status = "Inactivo" if user.estado == "Activo" else "Activo"
    user_update = schemas.UsuarioUpdate(estado=new_status)
    updated = crud.update_user(db, db_user=user, user_in=user_update)
    crud.log_audit(db, usuario_id=current_admin.id, accion=f"CAMBIAR_ESTADO_USUARIO {new_status} (id:{user_id})", tabla="usuarios", registro_id=user_id)
    return updated

@router.get("/categories", response_model=List[schemas.CategoriaResponse])
def list_categories(current_admin: Usuario = Depends(get_current_admin), db: Session = Depends(get_db)):
    return db.query(Categoria).all()

@router.post("/categories", response_model=schemas.CategoriaResponse, status_code=status.HTTP_201_CREATED)
def create_category(cat_in: schemas.CategoriaCreate, current_admin: Usuario = Depends(get_current_admin), db: Session = Depends(get_db)):
    existing = db.query(Categoria).filter(Categoria.nombre == cat_in.nombre).first()
    if existing:
        raise HTTPException(status_code=400, detail="Ya existe una categoria con este nombre.")
    cat = crud.create_categoria(db, nombre=cat_in.nombre, descripcion=cat_in.descripcion)
    crud.log_audit(db, usuario_id=current_admin.id, accion=f"CREAR_CATEGORIA ({cat.nombre})", tabla="categorias", registro_id=cat.id)
    return cat

@router.put("/categories/{cat_id}", response_model=schemas.CategoriaResponse)
def update_category(cat_id: int, cat_in: schemas.CategoriaCreate, current_admin: Usuario = Depends(get_current_admin), db: Session = Depends(get_db)):
    cat = db.query(Categoria).filter(Categoria.id == cat_id).first()
    if not cat:
        raise HTTPException(status_code=404, detail="Categoria no encontrada.")
    cat.nombre = cat_in.nombre
    cat.descripcion = cat_in.descripcion
    db.add(cat)
    db.commit()
    db.refresh(cat)
    return cat
