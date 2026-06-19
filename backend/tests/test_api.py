import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.core.database import Base, get_db
from app.core.config import settings
from app.core.security import get_password_hash
from app.core.models import Rol, Categoria, Usuario

# Configurar motor de base de datos para pruebas
# Se utiliza la base de datos de desarrollo por simplicidad de dependencias (PostGIS obligatorio)
# pero se ejecutan todas las pruebas dentro de transacciones que hacen ROLLBACK al finalizar.
engine = create_engine(settings.SQLALCHEMY_DATABASE_URI)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

@pytest.fixture(scope="session", autouse=True)
def setup_test_db():
    """Asegura que los roles y categorías existen antes de correr los tests."""
    db = TestingSessionLocal()
    # Asegurar roles
    for r_id, r_name in [(1, "Vecino"), (2, "Administrador")]:
        existing = db.query(Rol).filter(Rol.id == r_id).first()
        if not existing:
            db.add(Rol(id=r_id, nombre=r_name))
    # Asegurar categorías
    for c_id, c_name in [(1, "Robo"), (8, "Otro")]:
        existing = db.query(Categoria).filter(Categoria.id == c_id).first()
        if not existing:
            db.add(Categoria(id=c_id, nombre=c_name))
    db.commit()
    db.close()

@pytest.fixture
def db_session():
    """Crea una sesión de base de datos limpia para una prueba con rollback automático."""
    connection = engine.connect()
    transaction = connection.begin()
    session = TestingSessionLocal(bind=connection)
    
    yield session
    
    session.close()
    transaction.rollback()
    connection.close()

@pytest.fixture
def client(db_session):
    """Sobrescribe la dependencia get_db de FastAPI para usar la sesión de pruebas."""
    def override_get_db():
        try:
            yield db_session
        finally:
            pass
            
    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    app.dependency_overrides.clear()

# --- PRUEBAS DE AUTENTICACIÓN ---

def test_register_user(client):
    """Prueba el registro correcto de un nuevo usuario Vecino."""
    response = client.post(
        "/api/v1/auth/register",
        json={
            "nombre": "Test",
            "apellido": "User",
            "ci": "9998887",
            "celular": "76543210",
            "correo": "testuser@gmail.com",
            "contrasena": "Password123"
        }
    )
    assert response.statusCode == 201 or response.status_code == 201
    data = response.json()
    assert data["correo"] == "testuser@gmail.com"
    assert data["rol_id"] == 1 # Vecino
    assert data["estado"] == "Activo"

def test_login_user(client, db_session):
    """Prueba el inicio de sesión y la devolución de un token JWT."""
    # Crear usuario de prueba pre-existente en la sesión
    hashed = get_password_hash("SecretPassword")
    user = Usuario(
        nombre="Login",
        apellido="Tester",
        ci="1111122",
        celular="77700011",
        correo="login@test.com",
        contrasena=hashed,
        rol_id=1,
        estado="Activo"
    )
    db_session.add(user)
    db_session.commit()

    response = client.post(
        "/api/v1/auth/login",
        json={
            "correo": "login@test.com",
            "contrasena": "SecretPassword"
        }
    )
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["usuario"]["correo"] == "login@test.com"

# --- PRUEBAS DE INCIDENTES Y PÁNICO ---

def test_create_incident(client, db_session):
    """Prueba la creación de un incidente vecinal común por un usuario autenticado."""
    # Crear y loguear usuario
    hashed = get_password_hash("SecretPassword")
    user = Usuario(
        nombre="Reporter",
        apellido="Tester",
        ci="3333333",
        celular="77700033",
        correo="reporter@test.com",
        contrasena=hashed,
        rol_id=1,
        estado="Activo"
    )
    db_session.add(user)
    db_session.commit()

    # Login para obtener token
    login_res = client.post(
        "/api/v1/auth/login",
        json={"correo": "reporter@test.com", "contrasena": "SecretPassword"}
    )
    token = login_res.json()["access_token"]

    # Reportar incidente
    response = client.post(
        "/api/v1/incidents/",
        headers={"Authorization": f"Bearer {token}"},
        data={
            "categoria_id": 1, # Robo
            "descripcion": "Robo presenciado en la esquina del mercado de Ventilla.",
            "latitud": -16.621,
            "longitud": -68.212,
            "direccion": "Calle 10, Ventilla"
        }
    )
    assert response.status_code == 201
    data = response.json()
    assert data["descripcion"] == "Robo presenciado en la esquina del mercado de Ventilla."
    assert "nivel_riesgo" in data  # Debería correr la predicción IA

def test_panic_button(client, db_session):
    """Prueba la activación del botón de pánico (debe reportar en < 2 segundos e imponer nivel de riesgo prioritario)."""
    # Crear y loguear usuario
    hashed = get_password_hash("SecretPassword")
    user = Usuario(
        nombre="Panic",
        apellido="Tester",
        ci="4444444",
        celular="77700044",
        correo="panic@test.com",
        contrasena=hashed,
        rol_id=1,
        estado="Activo"
    )
    db_session.add(user)
    db_session.commit()

    login_res = client.post(
        "/api/v1/auth/login",
        json={"correo": "panic@test.com", "contrasena": "SecretPassword"}
    )
    token = login_res.json()["access_token"]

    import time
    start_time = time.time()
    
    # Activar botón de pánico
    response = client.post(
        "/api/v1/incidents/panic",
        headers={"Authorization": f"Bearer {token}"},
        data={
            "latitud": -16.602,
            "longitud": -68.198,
            "direccion": "Puente Vela"
        }
    )
    
    duration = time.time() - start_time
    
    assert response.status_code == 201
    assert duration < 2.0  # El tiempo total de procesamiento debe ser inferior a 2 segundos
    data = response.json()
    assert data["nivel_riesgo"] == "Alto"  # Pánico se clasifica automáticamente como riesgo Alto
    assert data["categoria_id"] == 8  # Otro / Emergencia
