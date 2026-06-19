-- Habilitar extensión PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;

-- Tabla: roles
CREATE TABLE IF NOT EXISTS roles (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) UNIQUE NOT NULL,
    descripcion TEXT
);

-- Tabla: categorias
CREATE TABLE IF NOT EXISTS categorias (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) UNIQUE NOT NULL,
    descripcion TEXT
);

-- Tabla: usuarios
CREATE TABLE IF NOT EXISTS usuarios (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    ci VARCHAR(20) UNIQUE NOT NULL,
    celular VARCHAR(20) NOT NULL,
    correo VARCHAR(100) UNIQUE NOT NULL,
    contrasena VARCHAR(255) NOT NULL,
    rol_id INTEGER REFERENCES roles(id) ON DELETE RESTRICT,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estado VARCHAR(20) DEFAULT 'Activo'
);

-- Tabla: incidentes
CREATE TABLE IF NOT EXISTS incidentes (
    id SERIAL PRIMARY KEY,
    usuario_id INTEGER REFERENCES usuarios(id) ON DELETE SET NULL,
    categoria_id INTEGER REFERENCES categorias(id) ON DELETE RESTRICT,
    descripcion TEXT NOT NULL,
    latitud DOUBLE PRECISION NOT NULL,
    longitud DOUBLE PRECISION NOT NULL,
    geom GEOMETRY(Point, 4326),
    direccion VARCHAR(255) NOT NULL,
    imagen VARCHAR(500),
    fecha_reporte TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estado VARCHAR(50) NOT NULL DEFAULT 'Pendiente',
    nivel_riesgo VARCHAR(20) NOT NULL DEFAULT 'Bajo'
);

-- Tabla: predicciones
CREATE TABLE IF NOT EXISTS predicciones (
    id SERIAL PRIMARY KEY,
    latitud DOUBLE PRECISION NOT NULL,
    longitud DOUBLE PRECISION NOT NULL,
    hora INTEGER NOT NULL,
    dia_semana INTEGER NOT NULL,
    categoria_id INTEGER REFERENCES categorias(id) ON DELETE CASCADE,
    nivel_riesgo_predicho VARCHAR(20) NOT NULL,
    accuracy DOUBLE PRECISION,
    precision_score DOUBLE PRECISION,
    recall DOUBLE PRECISION,
    f1_score DOUBLE PRECISION,
    fecha_prediccion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla: alertas
CREATE TABLE IF NOT EXISTS alertas (
    id SERIAL PRIMARY KEY,
    incidente_id INTEGER REFERENCES incidentes(id) ON DELETE CASCADE,
    titulo VARCHAR(255) NOT NULL,
    mensaje TEXT NOT NULL,
    fecha_envio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    tipo VARCHAR(50) DEFAULT 'Push'
);

-- Tabla: notificaciones
CREATE TABLE IF NOT EXISTS notificaciones (
    id SERIAL PRIMARY KEY,
    usuario_id INTEGER REFERENCES usuarios(id) ON DELETE CASCADE,
    alerta_id INTEGER REFERENCES alertas(id) ON DELETE CASCADE,
    leida BOOLEAN DEFAULT FALSE,
    fecha_recepcion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla: historial_incidentes
CREATE TABLE IF NOT EXISTS historial_incidentes (
    id SERIAL PRIMARY KEY,
    incidente_id INTEGER REFERENCES incidentes(id) ON DELETE CASCADE,
    estado_anterior VARCHAR(50),
    estado_nuevo VARCHAR(50) NOT NULL,
    usuario_cambio_id INTEGER REFERENCES usuarios(id) ON DELETE SET NULL,
    comentario TEXT,
    fecha_cambio TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla: auditoria
CREATE TABLE IF NOT EXISTS auditoria (
    id SERIAL PRIMARY KEY,
    usuario_id INTEGER REFERENCES usuarios(id) ON DELETE SET NULL,
    accion VARCHAR(100) NOT NULL,
    tabla_afectada VARCHAR(100) NOT NULL,
    registro_id INTEGER,
    ip_origen VARCHAR(45),
    fecha_accion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla: tokens_recuperacion
CREATE TABLE IF NOT EXISTS tokens_recuperacion (
    id SERIAL PRIMARY KEY,
    usuario_id INTEGER REFERENCES usuarios(id) ON DELETE CASCADE,
    token VARCHAR(255) NOT NULL,
    expiracion TIMESTAMP NOT NULL,
    utilizado BOOLEAN DEFAULT FALSE
);

-- Índices para optimizar búsquedas espaciales y filtros comunes
CREATE INDEX IF NOT EXISTS idx_incidentes_geom ON incidentes USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_incidentes_fecha ON incidentes (fecha_reporte);
CREATE INDEX IF NOT EXISTS idx_incidentes_estado ON incidentes (estado);
CREATE INDEX IF NOT EXISTS idx_usuarios_correo ON usuarios (correo);
CREATE INDEX IF NOT EXISTS idx_usuarios_ci ON usuarios (ci);
CREATE INDEX IF NOT EXISTS idx_tokens_token ON tokens_recuperacion (token);

-- Insertar roles iniciales obligatorios
INSERT INTO roles (id, nombre, descripcion) VALUES
(1, 'Vecino', 'Usuario ciudadano del Distrito 8 que reporta incidentes')
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre;

INSERT INTO roles (id, nombre, descripcion) VALUES
(2, 'Administrador', 'Usuario administrativo con acceso a gestión y reportes')
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre;

-- Insertar categorías iniciales obligatorias
INSERT INTO categorias (id, nombre, descripcion) VALUES
(1, 'Robo', 'Sustracción de bienes sin violencia directa hacia las personas'),
(2, 'Agresión', 'Violencia física directa entre personas'),
(3, 'Asalto', 'Robo con intimidación, amenaza o uso de armas'),
(4, 'Violencia', 'Violencia familiar, doméstica o de género en vía pública/domicilio'),
(5, 'Vandalismo', 'Daño a propiedad pública o privada, disturbios'),
(6, 'Accidente', 'Accidentes de tránsito o viales'),
(7, 'Emergencia médica', 'Casos de salud de urgencia en la vía pública'),
(8, 'Otro', 'Otros incidentes que atentan contra la seguridad ciudadana')
ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre;
