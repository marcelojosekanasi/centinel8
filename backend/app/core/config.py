import os
from typing import Optional
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import EmailStr, field_validator

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", extra="ignore"
    )

    PROJECT_NAME: str = "Centinel8 - Sistema Inteligente de Alerta Vecinal"
    API_V1_STR: str = "/api/v1"
    
    # JWT & Seguridad
    SECRET_KEY: str = "SUPER_SECRET_KEY_CENTINEL8_PROD_12345!@#$%"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 días
    
    # Base de Datos
    POSTGRES_SERVER: str = "localhost"
    POSTGRES_USER: str = "postgres"
    POSTGRES_PASSWORD: str = "postgres"
    POSTGRES_DB: str = "centinel8_db"
    POSTGRES_PORT: str = "5432"
    SQLALCHEMY_DATABASE_URI: Optional[str] = None

    @field_validator("SQLALCHEMY_DATABASE_URI", mode="before")
    @classmethod
    def assemble_db_connection(cls, v: Optional[str], values) -> str:
        if isinstance(v, str) and v:
            return v
        data = values.data
        server = data.get("POSTGRES_SERVER")
        user = data.get("POSTGRES_USER")
        password = data.get("POSTGRES_PASSWORD")
        db = data.get("POSTGRES_DB")
        port = data.get("POSTGRES_PORT")
        return f"postgresql://{user}:{password}@{server}:{port}/{db}"

    # Correo Electrónico (Recuperación y verificación)
    SMTP_TLS: bool = True
    SMTP_PORT: int = 587
    SMTP_HOST: Optional[str] = None
    SMTP_USER: Optional[str] = None
    SMTP_PASSWORD: Optional[str] = None
    EMAILS_FROM_EMAIL: Optional[EmailStr] = None
    EMAILS_FROM_NAME: Optional[str] = "Centinel8 Alerta Vecinal"

    # Firebase Cloud Messaging
    FCM_CREDENTIALS_JSON: Optional[str] = None  # JSON de Firebase en formato string o ruta de archivo

    # Configuración del Modelo IA
    MODEL_PATH: str = "app/ml/model.pkl"
    METRICS_PATH: str = "app/ml/metrics.json"

settings = Settings()
