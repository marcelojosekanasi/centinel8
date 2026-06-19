from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker
from app.core.config import settings

# Crear el motor de SQLAlchemy
engine = create_engine(
    settings.SQLALCHEMY_DATABASE_URI,
    pool_pre_ping=True,
    pool_size=10,
    max_overflow=20
)

# Creador de sesiones
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Clase Base declarativa
Base = declarative_base()

# Dependencia para obtener la sesión de BD en FastAPI
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
