# Centinel8 - Sistema Inteligente de Alerta Vecinal

**Centinel8** es una plataforma de producción integral diseñada para la **Subalcaldía del Distrito 8 de la ciudad de El Alto, Bolivia**. Su objetivo principal es fortalecer la seguridad ciudadana a través de reportes vecinales en tiempo real, geolocalización avanzada, activación instantánea de alertas (Botón de Pánico) y análisis predictivo mediante inteligencia artificial (capas neuronales artificiales - MLP) para estimar riesgos de inseguridad en la zona.

---

## 🚀 Arquitectura Tecnológica

El sistema se compone de los siguientes elementos listos para producción:

1. **Backend API REST**: 
   - **Python FastAPI**: Para una API asíncrona de alto desempeño.
   - **SQLAlchemy (ORM)**: Modelado relacional mapeado a objetos.
   - **Alembic**: Gestión e historial de migraciones de esquemas.
   - **JWT & BCrypt**: Autenticación segura y hashing de contraseñas.
   - **SlowAPI**: Límite de peticiones (Rate Limiting) contra ataques de fuerza bruta.
2. **Base de Datos**:
   - **PostgreSQL**: Motor relacional robusto.
   - **PostGIS**: Extensión espacial para almacenar geometrías de puntos y realizar búsquedas de proximidad geográfica (e.g. vecinos en un radio de 500 metros).
3. **Módulo de Inteligencia Artificial**:
   - **Scikit-Learn (MLPClassifier)**: Clasificador de perceptrón multicapa que predice niveles de riesgo (Bajo, Medio, Alto) analizando la hora, el día de la semana, la categoría del incidente, y las coordenadas (latitud y longitud).
4. **Frontend Móvil**:
   - **Flutter & Material Design 3**: UI moderna y de alto rendimiento adaptable a iOS y Android.
   - **OpenStreetMap (OSM)**: Cartografía interactiva offline/online para visualizar zonas críticas y heatmaps dinámicos.
   - **Firebase Cloud Messaging (FCM)**: Gestión de notificaciones push de emergencia.

---

## 📂 Estructura de Directorios del Proyecto

```
proyecto-integrador/
│
├── backend/                       # Directorio del Backend (FastAPI)
│   ├── app/
│   │   ├── api/v1/endpoints/      # Rutas REST de la API (/auth, /users, /incidents, /predictions, etc.)
│   │   ├── core/                  # Configuraciones, base de datos, modelos, seguridad y esquemas
│   │   ├── ml/                    # Lógica del MLPClassifier (entrenamiento y archivos pickle)
│   │   ├── utils/                 # Generación de reportes y envío de notificaciones push (FCM)
│   │   └── main.py                # Punto de entrada de FastAPI y Middlewares
│   │
│   ├── alembic/                   # Directorio de migraciones autogeneradas
│   ├── tests/                     # Pruebas de integración automatizadas con pytest
│   ├── requirements.txt           # Dependencias de Python
│   ├── Dockerfile                 # Contenedor optimizado para FastAPI + Scikit-Learn
│   ├── alembic.ini                # Archivo de configuración de Alembic
│   └── backend_seed.py            # Semillero de incidentes georreferenciados en el Distrito 8
│
├── frontend/                      # Directorio del App Móvil (Flutter)
│   ├── lib/
│   │   ├── providers/             # Manejadores de Estado (AuthProvider, etc.)
│   │   ├── screens/               # Pantallas (Splash, Login, Panic, Map, Dashboard, etc.)
│   │   ├── services/              # Servicio de red REST (ApiService)
│   │   └── main.dart              # Inicialización, Temas MD3 y Enrutador
│   └── pubspec.yaml               # Dependencias de Flutter (flutter_map, geolocator, fl_chart, etc.)
│
├── database/                      # Scripts de la Base de Datos
│   ├── init.sql                   # Estructura del esquema e inserción de roles/categorías iniciales
│   └── init-db.sh                 # Inicialización de extensiones PostGIS en Docker
│
├── scripts/                       # Herramientas de infraestructura
│   └── deploy.sh                  # Script de instalación automatizada en servidores Ubuntu 24.04
│
├── docker-compose.yml             # Orquestación de contenedores (Base de datos + API)
├── .env.example                   # Plantilla de variables de entorno
└── README.md                      # Este manual técnico
```

---

## 🛠️ Instalación y Configuración Local

### Prerrequisitos
- **Python 3.10 o superior**
- **Flutter SDK (3.0.0+)**
- **PostgreSQL con la extensión PostGIS instalada localmente** (si no usa Docker)

### 1. Configuración del Backend

1. Navegue al directorio de backend y cree un entorno virtual:
   ```bash
   cd backend
   python -m venv venv
   # En Windows
   .\venv\Scripts\activate
   # En Linux/macOS
   source venv/bin/activate
   ```
2. Instale las dependencias de Python:
   ```bash
   pip install --upgrade pip
   pip install -r requirements.txt
   ```
3. Cree un archivo `.env` en la raíz del proyecto basándose en `.env.example`:
   ```bash
   cp ../.env.example ../.env
   ```
   *Nota: Configure las credenciales de PostgreSQL y opcionalmente las de Firebase/SMTP.*
4. Sembrar la base de datos local (crea usuarios de prueba y 65 incidentes históricos distribuidos en Senkata, Ventilla y Puente Vela del Distrito 8, entrenando el modelo de IA automáticamente):
   ```bash
   python backend_seed.py
   ```
5. Ejecutar la API REST localmente:
   ```bash
   uvicorn app.main:app --reload --port 8000
   ```
   *La API estará disponible en `http://localhost:8000`. Acceda al Swagger interactivo en `http://localhost:8000/docs`.*

### 2. Configuración del Frontend Flutter

1. Navegue al directorio del frontend:
   ```bash
   cd ../frontend
   ```
2. Obtenga los paquetes de Flutter:
   ```bash
   flutter pub get
   ```
3. Ejecute el app en un emulador o dispositivo físico conectado:
   ```bash
   flutter run
   ```
   *Nota: Por defecto, el archivo [api_service.dart](file:///c:/PROYECTO%20INTEGRADOR/frontend/lib/services/api_service.dart) apunta a `http://10.0.2.2:8000/api/v1` (dirección que mapea al localhost de la máquina host desde el emulador de Android). Si despliega en red física, cambie el valor de `defaultBaseUrl`.*

---

## 🐳 Despliegue con Docker Compose (Recomendado)

1. Asegúrese de tener Docker y Docker Compose instalados.
2. Copie y configure su archivo `.env` en el directorio raíz.
3. Inicie el despliegue de contenedores:
   ```bash
   docker compose up --build -d
   ```
   *Este comando levantará:*
   - Un contenedor con **PostgreSQL + PostGIS** (`centinel8_db_container`), ejecutando los esquemas e índices espaciales de `init.sql`.
   - Un contenedor con el **Backend FastAPI** (`centinel8_backend_container`), que entrena automáticamente el modelo MLPClassifier en su primer arranque.
4. Para sembrar los datos demo del Distrito 8 en los contenedores levantados, corra:
   ```bash
   docker exec -it centinel8_backend_container python backend_seed.py
   ```

---

## 🖥️ Despliegue Automatizado en Ubuntu 24.04 LTS

Para desplegar de manera inmediata en un servidor en la nube con Ubuntu 24.04, proveemos un script automatizado en la carpeta `scripts/`:

```bash
cd scripts
sudo chmod +x deploy.sh
sudo ./deploy.sh
```

El script se encargará de:
1. Actualizar el gestor de paquetes de Ubuntu.
2. Instalar el motor de Docker y el plugin de Docker Compose si no existen en el servidor.
3. Configurar un archivo `.env` de producción con llaves seguras autogeneradas.
4. Levantar la pila de contenedores (`db` + `backend`).
5. Poblar la base de datos de PostGIS con el historial de incidentes y pre-entrenar la Inteligencia Artificial.

---

## 🧠 Lógica de la Inteligencia Artificial (MLPClassifier)

El clasificador **MLP (Perceptrón Multicapa)** se entrena con los campos:
- **Hora del incidente** (0 - 23)
- **Día de la semana** (0 - 6)
- **Categoría** (1 - 8)
- **Latitud y Longitud** (coordenadas geográficas)

La salida es una clasificación discreta que determina el nivel de riesgo: **Bajo**, **Medio** o **Alto**.
- **Entrenamiento Automático**: Si no se detecta el modelo entrenado (`model.pkl`) al iniciar el backend, se entrena usando los registros de incidentes de la base de datos. Si no hay suficientes registros (< 10), el sistema autogenera una base sintética geolocalizada en el Distrito 8 para arrancar de forma segura.
- **Reentrenamiento Manual**: Los administradores pueden presionar "Reentrenar IA" en el panel para re-entrenar el modelo con los nuevos reportes del día a día, guardando métricas de precisión y recall.

---

## 🔒 Detalles de Seguridad

- **BCrypt**: Hashing de contraseñas de vecinos con factores de costo adaptables.
- **JWT**: Tokens de sesión firmados digitalmente (algoritmo HS256) con expiraciones automáticas.
- **PostGIS Indexing**: Índice GIST en la columna `geom` de incidentes para búsquedas espaciales ultra-rápidas.
- **SlowAPI Rate-Limiting**: Límites por dirección IP en el inicio de sesión y registro para mitigar abuso.
- **Auditoría**: Cada acción crítica (registro, login, pánico, actualización de estados, entrenamiento de IA) se registra en la tabla `auditoria` con la IP de origen y la marca temporal correspondientes.

---

## 👥 Usuarios de Prueba Creados por el Semillero

Si ejecuta el script de sembrado (`backend_seed.py`), puede acceder usando las siguientes credenciales por defecto:

*   **Vecino de Prueba**:
    *   **Correo**: `vecino1@gmail.com`
    *   **Contraseña**: `Vecino123*`
*   **Administrador de Prueba**:
    *   **Correo**: `admin@centinel8.bo`
    *   **Contraseña**: `Admin123*`
