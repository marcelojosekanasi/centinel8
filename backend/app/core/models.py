from sqlalchemy import Column, Integer, String, Text, Double, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from geoalchemy2 import Geometry
from app.core.database import Base

class Rol(Base):
    __tablename__ = "roles"
    
    id = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(50), unique=True, nullable=False)
    descripcion = Column(Text, nullable=True)
    
    usuarios = relationship("Usuario", back_populates="rol")

class Categoria(Base):
    __tablename__ = "categorias"
    
    id = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(100), unique=True, nullable=False)
    descripcion = Column(Text, nullable=True)
    
    incidentes = relationship("Incidente", back_populates="categoria")
    predicciones = relationship("Prediccion", back_populates="categoria")

class Usuario(Base):
    __tablename__ = "usuarios"
    
    id = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(100), nullable=False)
    apellido = Column(String(100), nullable=False)
    ci = Column(String(20), unique=True, nullable=False, index=True)
    celular = Column(String(20), nullable=False)
    correo = Column(String(100), unique=True, nullable=False, index=True)
    contrasena = Column(String(255), nullable=False)
    rol_id = Column(Integer, ForeignKey("roles.id", ondelete="RESTRICT"), nullable=False)
    fecha_registro = Column(DateTime(timezone=True), server_default=func.now())
    estado = Column(String(20), default="Activo")  # Activo, Inactivo, Pendiente
    
    rol = relationship("Rol", back_populates="usuarios")
    incidentes = relationship("Incidente", back_populates="usuario")
    notificaciones = relationship("Notificacion", back_populates="usuario")
    tokens_recuperacion = relationship("TokenRecuperacion", back_populates="usuario")
    auditorias = relationship("Auditoria", back_populates="usuario")
    dispositivos_fcm = relationship("DispositivoFCM", back_populates="usuario")

class Incidente(Base):
    __tablename__ = "incidentes"
    
    id = Column(Integer, primary_key=True, index=True)
    usuario_id = Column(Integer, ForeignKey("usuarios.id", ondelete="SET NULL"), nullable=True)
    categoria_id = Column(Integer, ForeignKey("categorias.id", ondelete="RESTRICT"), nullable=False)
    descripcion = Column(Text, nullable=False)
    latitud = Column(Double, nullable=False)
    longitud = Column(Double, nullable=False)
    geom = Column(Geometry(geometry_type="POINT", srid=4326), nullable=True)
    direccion = Column(String(255), nullable=False)
    imagen = Column(String(500), nullable=True)
    fecha_reporte = Column(DateTime(timezone=True), server_default=func.now(), index=True)
    estado = Column(String(50), nullable=False, default="Pendiente")  # Pendiente, En proceso, Atendido, Cerrado
    nivel_riesgo = Column(String(20), nullable=False, default="Bajo")  # Bajo, Medio, Alto
    
    usuario = relationship("Usuario", back_populates="incidentes")
    categoria = relationship("Categoria", back_populates="incidentes")
    alertas = relationship("Alerta", back_populates="incidente")
    historial = relationship("HistorialIncidente", back_populates="incidente")

class Prediccion(Base):
    __tablename__ = "predicciones"
    
    id = Column(Integer, primary_key=True, index=True)
    latitud = Column(Double, nullable=False)
    longitud = Column(Double, nullable=False)
    hora = Column(Integer, nullable=False)
    dia_semana = Column(Integer, nullable=False)
    categoria_id = Column(Integer, ForeignKey("categorias.id", ondelete="CASCADE"), nullable=False)
    nivel_riesgo_predicho = Column(String(20), nullable=False)
    accuracy = Column(Double, nullable=True)
    precision_score = Column(Double, nullable=True)
    recall = Column(Double, nullable=True)
    f1_score = Column(Double, nullable=True)
    fecha_prediccion = Column(DateTime(timezone=True), server_default=func.now())
    
    categoria = relationship("Categoria", back_populates="predicciones")

class Alerta(Base):
    __tablename__ = "alertas"
    
    id = Column(Integer, primary_key=True, index=True)
    incidente_id = Column(Integer, ForeignKey("incidentes.id", ondelete="CASCADE"), nullable=True)
    titulo = Column(String(255), nullable=False)
    mensaje = Column(Text, nullable=False)
    fecha_envio = Column(DateTime(timezone=True), server_default=func.now())
    tipo = Column(String(50), default="Push")  # Push, Panico
    
    incidente = relationship("Incidente", back_populates="alertas")
    notificaciones = relationship("Notificacion", back_populates="alerta")

class Notificacion(Base):
    __tablename__ = "notificaciones"
    
    id = Column(Integer, primary_key=True, index=True)
    usuario_id = Column(Integer, ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    alerta_id = Column(Integer, ForeignKey("alertas.id", ondelete="CASCADE"), nullable=False)
    leida = Column(Boolean, default=False)
    fecha_recepcion = Column(DateTime(timezone=True), server_default=func.now())
    
    usuario = relationship("Usuario", back_populates="notificaciones")
    alerta = relationship("Alerta", back_populates="notificaciones")

class HistorialIncidente(Base):
    __tablename__ = "historial_incidentes"
    
    id = Column(Integer, primary_key=True, index=True)
    incidente_id = Column(Integer, ForeignKey("incidentes.id", ondelete="CASCADE"), nullable=False)
    estado_anterior = Column(String(50), nullable=True)
    estado_nuevo = Column(String(50), nullable=False)
    usuario_cambio_id = Column(Integer, ForeignKey("usuarios.id", ondelete="SET NULL"), nullable=True)
    comentario = Column(Text, nullable=True)
    fecha_cambio = Column(DateTime(timezone=True), server_default=func.now())
    
    incidente = relationship("Incidente", back_populates="historial")

class Auditoria(Base):
    __tablename__ = "auditoria"
    
    id = Column(Integer, primary_key=True, index=True)
    usuario_id = Column(Integer, ForeignKey("usuarios.id", ondelete="SET NULL"), nullable=True)
    accion = Column(String(100), nullable=False)
    tabla_afectada = Column(String(100), nullable=False)
    registro_id = Column(Integer, nullable=True)
    ip_origen = Column(String(45), nullable=True)
    fecha_accion = Column(DateTime(timezone=True), server_default=func.now())
    
    usuario = relationship("Usuario", back_populates="auditorias")

class TokenRecuperacion(Base):
    __tablename__ = "tokens_recuperacion"
    
    id = Column(Integer, primary_key=True, index=True)
    usuario_id = Column(Integer, ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    token = Column(String(255), nullable=False, index=True)
    expiracion = Column(DateTime(timezone=True), nullable=False)
    utilizado = Column(Boolean, default=False)
    
    usuario = relationship("Usuario", back_populates="tokens_recuperacion")

class DispositivoFCM(Base):
    __tablename__ = "dispositivos_fcm"

    id = Column(Integer, primary_key=True, index=True)
    usuario_id = Column(Integer, ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    token = Column(String(255), unique=True, nullable=False, index=True)
    plataforma = Column(String(20), nullable=False, default="android")  # android, ios
    fecha_registro = Column(DateTime(timezone=True), server_default=func.now())
    activo = Column(Boolean, default=True)

    usuario = relationship("Usuario", back_populates="dispositivos_fcm")
