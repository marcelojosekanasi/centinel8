import random
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.core.database import SessionLocal, engine
from app.core.models import Base, Rol, Categoria, Usuario, Incidente, HistorialIncidente
from app.core.security import get_password_hash

# Coordenadas y direcciones del Distrito 8 de El Alto, Bolivia
# Bounding Box aproximado: Latitudes [-16.55, -16.65], Longitudes [-68.15, -68.25]
D8_ZONAS = [
    {"direccion": "Av. 6 de Marzo, Ex-Tranca de Senkata", "lat": -16.582, "lng": -68.185},
    {"direccion": "Av. Bolivia, Cruce Villa Adela - Senkata", "lat": -16.571, "lng": -68.179},
    {"direccion": "Calle 10, Mercado Ventilla", "lat": -16.621, "lng": -68.212},
    {"direccion": "Av. Integración, Parada Minibuses Puente Vela", "lat": -16.602, "lng": -68.198},
    {"direccion": "Calle Abaroa, Zona Tarapacá D8", "lat": -16.561, "lng": -68.169},
    {"direccion": "Av. Unificada, Plaza Principal Senkata 79", "lat": -16.589, "lng": -68.190},
    {"direccion": "Av. Litoral, Cruce Ventilla", "lat": -16.615, "lng": -68.208},
    {"direccion": "Calle Aroma, Barrio Parcopata", "lat": -16.634, "lng": -68.225},
    {"direccion": "Av. Versalles, Urbanización Las Delicias D8", "lat": -16.595, "lng": -68.202},
    {"direccion": "Calle Cochabamba, Cerca Unidad Educativa República de Rusia", "lat": -16.578, "lng": -68.181}
]

DESCRIPCIONES = {
    1: [ # Robo
        "Robo de accesorios de vehículo estacionado en la calle.",
        "Robo de garrafa de gas de un domicilio particular.",
        "Sustracción de mercadería en puesto de venta del mercado."
    ],
    2: [ # Agresión
        "Pelea callejera entre personas en estado de ebriedad.",
        "Agresión física de grupo de jóvenes a un transeúnte.",
        "Discusión y golpes entre choferes de minibús en la parada."
    ],
    3: [ # Asalto
        "Asalto a mano armada por dos antisociales en motocicleta.",
        "Atraco con arma blanca a un estudiante saliendo del colegio.",
        "Asalto grupal en pasarela peatonal aprovechando la falta de luz."
    ],
    4: [ # Violencia
        "Caso de violencia familiar/intrafamiliar con gritos de auxilio.",
        "Violencia doméstica en domicilio, agresor ebrio amenaza a su pareja.",
        "Maltrato físico en la vía pública hacia una mujer."
    ],
    5: [ # Vandalismo
        "Jóvenes grafiteando muros de la Unidad Educativa.",
        "Destrucción de luminarias públicas de la plaza principal.",
        "Rotura de vidrios de un minibús estacionado por disturbios."
    ],
    6: [ # Accidente
        "Choque de minibús contra un poste de energía eléctrica.",
        "Atropello a peatón por parte de una motocicleta que escapó.",
        "Colisión por alcance entre dos vehículos de transporte público."
    ],
    7: [ # Emergencia médica
        "Persona de la tercera edad se desmaya en plena acera.",
        "Ataque epiléptico de un ciudadano en la feria del barrio.",
        "Mujer entra en labor de parto en la parada de minibuses."
    ],
    8: [ # Otro
        "Sospechosos merodeando viviendas en actitud vigilante.",
        "Cables de alta tensión sueltos en el suelo tras tormenta.",
        "Quema de basura descontrolada que amenaza propagarse a viviendas."
    ]
}

def seed_db():
    print("Iniciando el sembrado de la base de datos de Centinel8...")
    db = SessionLocal()
    
    # 1. Asegurar roles
    roles = [
        {"id": 1, "nombre": "Vecino", "descripcion": "Usuario ciudadano del Distrito 8"},
        {"id": 2, "nombre": "Administrador", "descripcion": "Usuario administrativo con acceso a gestión"}
    ]
    for r in roles:
        existing = db.query(Rol).filter(Rol.id == r["id"]).first()
        if not existing:
            db.add(Rol(id=r["id"], nombre=r["nombre"], descripcion=r["descripcion"]))
    db.commit()
    print("- Roles sembrados.")

    # 2. Asegurar categorías
    categorias = [
        {"id": 1, "nombre": "Robo", "descripcion": "Robo sin violencia directa"},
        {"id": 2, "nombre": "Agresión", "descripcion": "Peleas y agresiones físicas"},
        {"id": 3, "nombre": "Asalto", "descripcion": "Atracos con violencia/armas"},
        {"id": 4, "nombre": "Violencia", "descripcion": "Violencia doméstica o callejera de género"},
        {"id": 5, "nombre": "Vandalismo", "descripcion": "Daños materiales en vía pública"},
        {"id": 6, "nombre": "Accidente", "descripcion": "Accidentes viales o de tránsito"},
        {"id": 7, "nombre": "Emergencia médica", "descripcion": "Emergencias de salud pública"},
        {"id": 8, "nombre": "Otro", "descripcion": "Otros incidentes prioritarios"}
    ]
    for c in categorias:
        existing = db.query(Categoria).filter(Categoria.id == c["id"]).first()
        if not existing:
            db.add(Categoria(id=c["id"], nombre=c["nombre"], descripcion=c["descripcion"]))
    db.commit()
    print("- Categorías sembradas.")

    # 3. Crear usuarios de prueba
    # Admin
    admin_email = "admin@centinel8.bo"
    existing_admin = db.query(Usuario).filter(Usuario.correo == admin_email).first()
    if not existing_admin:
        admin_user = Usuario(
            nombre="Admin",
            apellido="Centinel8",
            ci="8888888",
            celular="77712345",
            correo=admin_email,
            contrasena=get_password_hash("Admin123*"),
            rol_id=2, # Administrador
            estado="Activo"
        )
        db.add(admin_user)
        
    # Vecinos (5 vecinos de prueba)
    vecino_emails = ["vecino1@gmail.com", "vecino2@gmail.com", "vecino3@gmail.com", "vecino4@gmail.com", "vecino5@gmail.com"]
    vecinos_creados = []
    
    for i, email in enumerate(vecino_emails, 1):
        existing_v = db.query(Usuario).filter(Usuario.correo == email).first()
        if not existing_v:
            vecino = Usuario(
                nombre=f"Vecino {i}",
                apellido=f"El Alto {i}",
                ci=f"777777{i}",
                celular=f"6000000{i}",
                correo=email,
                contrasena=get_password_hash("Vecino123*"),
                rol_id=1, # Vecino
                estado="Activo"
            )
            db.add(vecino)
            vecinos_creados.append(vecino)
        else:
            vecinos_creados.append(existing_v)
            
    db.commit()
    print("- Usuarios administradores y vecinos de prueba creados.")

    # 4. Crear incidentes históricos para el MLP Classifier (65 incidentes simulados)
    print("- Generando 65 incidentes históricos del Distrito 8...")
    
    # Eliminar incidentes previos para evitar duplicados si se re-ejecuta
    db.query(HistorialIncidente).delete()
    db.query(Incidente).delete()
    db.commit()

    random.seed(101)
    estados = ["Pendiente", "En proceso", "Atendido", "Cerrado"]
    
    for idx in range(65):
        # Seleccionar vecino, zona y categoría aleatorios
        vecino = random.choice(vecinos_creados)
        zona = random.choice(D8_ZONAS)
        cat_id = random.randint(1, 8)
        
        # Variar levemente las coordenadas para simular diferentes puntos alrededor de las zonas
        lat_offset = random.uniform(-0.005, 0.005)
        lng_offset = random.uniform(-0.005, 0.005)
        lat = zona["lat"] + lat_offset
        lng = zona["lng"] + lng_offset
        
        # Dirección descriptiva
        dir_completa = f"{zona['direccion']} (Aprox. calle {random.randint(1,20)})"
        desc = random.choice(DESCRIPCIONES[cat_id])
        
        # Fecha en los últimos 30 días
        dias_atras = random.randint(0, 30)
        hora = random.randint(0, 23)
        minuto = random.randint(0, 59)
        fecha = datetime.now() - timedelta(days=dias_atras)
        fecha = fecha.replace(hour=hora, minute=minuto, second=0, microsecond=0)
        
        # Heurística para asignar el nivel de riesgo histórico real
        # Asaltos nocturnos, violencia intrafamiliar nocturna, peleas graves = riesgo Alto
        if (hora >= 20 or hora <= 5) and cat_id in [1, 2, 3]:
            nivel_riesgo = "Alto"
        elif cat_id in [1, 2, 3, 4] or (hora >= 18 or hora <= 6):
            nivel_riesgo = "Medio"
        else:
            nivel_riesgo = "Bajo"
            
        estado = random.choice(estados)
        
        # Inserción con PostGIS Point
        geom = func.ST_SetSRID(func.ST_MakePoint(lng, lat), 4326)
        
        inc = Incidente(
            usuario_id=vecino.id,
            categoria_id=cat_id,
            descripcion=desc,
            latitud=lat,
            longitud=lng,
            geom=geom,
            direccion=dir_completa,
            fecha_reporte=fecha,
            estado=estado,
            nivel_riesgo=nivel_riesgo
        )
        db.add(inc)
        db.flush() # Para obtener el ID del incidente creado
        
        # Registrar historial inicial
        hist_orig = HistorialIncidente(
            incidente_id=inc.id,
            estado_anterior=None,
            estado_nuevo="Pendiente",
            usuario_cambio_id=vecino.id,
            comentario="Incidente reportado por el ciudadano.",
            fecha_cambio=fecha
        )
        db.add(hist_orig)
        
        # Si el estado actual es avanzado, registrar cambio
        if estado != "Pendiente":
            hist_cambio = HistorialIncidente(
                incidente_id=inc.id,
                estado_anterior="Pendiente",
                estado_nuevo=estado,
                usuario_cambio_id=1, # Admin
                comentario=f"Cambio de estado procesado en el semillero.",
                fecha_cambio=fecha + timedelta(minutes=random.randint(30, 240))
            )
            db.add(hist_cambio)

    db.commit()
    print("- Base de datos sembrada con éxito.")
    
    # 5. Entrenar el modelo MLPClassifier con los datos recién cargados
    print("- Entrenando modelo de IA MLPClassifier con los datos sembrados...")
    from app.ml.model import predictor
    metrics = predictor.train_model(db)
    print(f"- Entrenamiento del modelo completado: Metrics={metrics}")
    
    db.close()
    print("Semillero completado exitosamente.")

if __name__ == "__main__":
    seed_db()
