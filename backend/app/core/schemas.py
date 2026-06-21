from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List, Dict, Any
from datetime import datetime

# --- Esquemas de Usuario y Auth ---

class UsuarioBase(BaseModel):
    nombre: str = Field(..., min_length=2, max_length=100)
    apellido: str = Field(..., min_length=2, max_length=100)
    ci: str = Field(..., min_length=5, max_length=20)
    celular: str = Field(..., min_length=7, max_length=20)
    correo: EmailStr

class UsuarioCreate(UsuarioBase):
    contrasena: str = Field(..., min_length=6, max_length=100)
    rol_id: int = Field(default=1)  # Por defecto 1 = Vecino

class UsuarioUpdate(BaseModel):
    nombre: Optional[str] = Field(None, min_length=2, max_length=100)
    apellido: Optional[str] = Field(None, min_length=2, max_length=100)
    celular: Optional[str] = Field(None, min_length=7, max_length=20)
    correo: Optional[EmailStr] = None
    contrasena: Optional[str] = Field(None, min_length=6, max_length=100)
    estado: Optional[str] = None  # Activo, Inactivo
    rol_id: Optional[int] = None  # 1=Vecino, 2=Administrador, 3=Policia

class RolResponse(BaseModel):
    id: int
    nombre: str
    descripcion: Optional[str] = None
    
    class Config:
        from_attributes = True

class UsuarioResponse(UsuarioBase):
    id: int
    rol_id: int
    fecha_registro: datetime
    estado: str
    rol: Optional[RolResponse] = None

    class Config:
        from_attributes = True

class LoginRequest(BaseModel):
    correo: EmailStr
    contrasena: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    usuario: UsuarioResponse

class RecuperarContrasenaRequest(BaseModel):
    correo: EmailStr

class RestablecerContrasenaRequest(BaseModel):
    token: str
    nueva_contrasena: str = Field(..., min_length=6, max_length=100)

class CambiarContrasenaRequest(BaseModel):
    contrasena_actual: str
    nueva_contrasena: str = Field(..., min_length=6, max_length=100)

# --- Esquemas de CategorÃ­a ---

class CategoriaResponse(BaseModel):
    id: int
    nombre: str
    descripcion: Optional[str] = None

    class Config:
        from_attributes = True

class CategoriaCreate(BaseModel):
    nombre: str
    descripcion: Optional[str] = None

# --- Esquemas de Incidente ---

class IncidenteBase(BaseModel):
    categoria_id: int
    descripcion: str = Field(..., min_length=10)
    latitud: float
    longitud: float
    direccion: str

class IncidenteCreate(IncidenteBase):
    imagen: Optional[str] = None

class IncidenteUpdate(BaseModel):
    estado: Optional[str] = None  # Pendiente, En proceso, Atendido, Cerrado
    nivel_riesgo: Optional[str] = None  # Bajo, Medio, Alto

class HistorialIncidenteResponse(BaseModel):
    id: int
    estado_anterior: Optional[str] = None
    estado_nuevo: str
    usuario_cambio_id: Optional[int] = None
    comentario: Optional[str] = None
    fecha_cambio: datetime

    class Config:
        from_attributes = True

class IncidenteResponse(IncidenteBase):
    id: int
    usuario_id: Optional[int] = None
    imagen: Optional[str] = None
    fecha_reporte: datetime
    estado: str
    nivel_riesgo: str
    usuario: Optional[UsuarioResponse] = None
    categoria: Optional[CategoriaResponse] = None
    historial: List[HistorialIncidenteResponse] = []

    class Config:
        from_attributes = True

# --- Esquemas de Alerta y NotificaciÃ³n ---

class AlertaResponse(BaseModel):
    id: int
    incidente_id: Optional[int] = None
    titulo: str
    mensaje: str
    fecha_envio: datetime
    tipo: str

    class Config:
        from_attributes = True

class NotificacionResponse(BaseModel):
    id: int
    usuario_id: int
    alerta_id: int
    leida: bool
    fecha_recepcion: datetime
    alerta: AlertaResponse

    class Config:
        from_attributes = True

# --- Esquemas de PredicciÃ³n ---

class PrediccionRequest(BaseModel):
    latitud: float
    longitud: float
    hora: int = Field(..., ge=0, le=23)
    dia_semana: int = Field(..., ge=0, le=6)  # 0=Lunes, 6=Domingo
    categoria_id: int

class PrediccionResponse(BaseModel):
    nivel_riesgo_predicho: str
    hora: int
    dia_semana: int
    latitud: float
    longitud: float
    categoria_id: int
    fecha_prediccion: datetime

    class Config:
        from_attributes = True

class TrainMetricsResponse(BaseModel):
    accuracy: float
    precision: float
    recall: float
    f1_score: float
    timestamp: str
    total_muestras: Optional[int] = None
    entrenado_con_sinteticos: Optional[bool] = None

# --- Esquemas del Dashboard Admin ---

class DashboardStats(BaseModel):
    total_usuarios: int
    total_incidentes: int
    incidentes_hoy: int
    incidentes_por_categoria: Dict[str, int]
    incidentes_por_estado: Dict[str, int]
    incidentes_recientes: List[IncidenteResponse]
    predicciones_totales: int


# --- Esquema de Dispositivo FCM (Push Notifications) ---

class DispositivoFCMCreate(BaseModel):
    token: str = Field(..., min_length=10)
    plataforma: str = Field(default="android")
