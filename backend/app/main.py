from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
import os

from app.core.config import settings
from app.api.v1.endpoints import auth, users, incidents, alerts, predictions, reports, dashboard, admin
from app.ml.model import predictor
from app.core.database import SessionLocal

# Inicializar rate-limiter
limiter = Limiter(key_func=get_remote_address)

# Crear app FastAPI
app = FastAPI(
    title=settings.PROJECT_NAME,
    description="Centinel8 - Sistema Inteligente de Alerta Vecinal mediante Geolocalización y Análisis Predictivo para la Subalcaldía del Distrito 8 de El Alto, Bolivia.",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Configurar rate limiter
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Middleware CORS para permitir solicitudes del app móvil y web
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Carpeta de carga de imágenes para incidentes
os.makedirs("static/uploads", exist_ok=True)
app.mount("/static", StaticFiles(directory="static"), name="static")

# Incluir enrutadores
app.include_router(auth.router, prefix=f"{settings.API_V1_STR}/auth", tags=["Autenticación"])
app.include_router(users.router, prefix=f"{settings.API_V1_STR}/users", tags=["Usuarios"])
app.include_router(incidents.router, prefix=f"{settings.API_V1_STR}/incidents", tags=["Incidentes & Botón de Pánico"])
app.include_router(alerts.router, prefix=f"{settings.API_V1_STR}/alerts", tags=["Alertas & Notificaciones"])
app.include_router(predictions.router, prefix=f"{settings.API_V1_STR}/predictions", tags=["Módulo Predictivo IA"])
app.include_router(reports.router, prefix=f"{settings.API_V1_STR}/reports", tags=["Módulo de Reportes"])
app.include_router(dashboard.router, prefix=f"{settings.API_V1_STR}/dashboard", tags=["Estadísticas Dashboard"])
app.include_router(admin.router, prefix=f"{settings.API_V1_STR}/admin", tags=["Administración de Categorías"])

@app.on_event("startup")
def startup_event():
    """Se ejecuta al levantar el servidor. Carga el modelo de IA o lo entrena si no existe."""
    db = SessionLocal()
    try:
        loaded = predictor.load_model()
        if not loaded:
            print("No se encontró un modelo previo. Ejecutando entrenamiento del MLPClassifier...")
            metrics = predictor.train_model(db)
            print(f"Modelo entrenado exitosamente. Accuracy: {metrics.get('accuracy'):.4f}")
        else:
            print(f"Modelo cargado correctamente desde disk. Métricas: {predictor.metrics}")
    except Exception as e:
        print(f"Error al inicializar el modelo de IA en el startup: {e}")
    finally:
        db.close()

@app.get("/")
def read_root():
    return {
        "sistema": "Centinel8",
        "version": "1.0.0",
        "subalcaldia": "Distrito 8 - El Alto",
        "estado": "Operativo",
        "documentacion": "/docs"
    }
