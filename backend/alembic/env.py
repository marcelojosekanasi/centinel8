import sys
from os.path import abspath, dirname
from logging.config import fileConfig

from sqlalchemy import engine_from_config
from sqlalchemy import pool
from alembic import context

# Agregar el directorio raíz del backend al path para poder importar app
sys.path.insert(0, abspath(dirname(dirname(__file__))))

from app.core.config import settings
from app.core.database import Base
# Importar modelos para registro automático en metadata
from app.core.models import (
    Usuario, Rol, Categoria, Incidente, Prediccion, 
    Alerta, Notificacion, HistorialIncidente, Auditoria, TokenRecuperacion
)

# Configurar logs de alembic si el archivo de configuración existe
config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata

def run_migrations_offline() -> None:
    """Ejecutar migraciones en modo 'offline' sin conectarse a la BD."""
    url = settings.SQLALCHEMY_DATABASE_URI
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()

def run_migrations_online() -> None:
    """Ejecutar migraciones conectándose a la base de datos en tiempo real."""
    configuration = config.get_section(config.config_ini_section) or {}
    # Sobrescribir la URL de conexión usando las configuraciones unificadas del proyecto
    configuration["sqlalchemy.url"] = settings.SQLALCHEMY_DATABASE_URI
    
    connectable = engine_from_config(
        configuration,
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection, 
            target_metadata=target_metadata
        )

        with context.begin_transaction():
            context.run_migrations()

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
