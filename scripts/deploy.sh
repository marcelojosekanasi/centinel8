#!/bin/bash
# -----------------------------------------------------------------------------
# Centinel8 - Script de Despliegue Automatizado para Ubuntu 24.04 LTS
# -----------------------------------------------------------------------------

set -e

# Colores para salida en consola
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # Sin color

echo -e "${BLUE}=== Iniciando Despliegue de Centinel8 ===${NC}"

# 1. Verificar si se ejecuta como root o con sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: Por favor ejecute este script con privilegios root (sudo).${NC}"
  exit 1
fi

# 2. Actualizar paquetes del sistema
echo -e "${GREEN}[1/6] Actualizando el sistema de paquetes...${NC}"
apt update && apt upgrade -y

# 3. Instalar Docker y dependencias si no están presentes
if ! [ -x "$(command -v docker)" ]; then
  echo -e "${GREEN}[2/6] Docker no detectado. Instalando Docker Engine...${NC}"
  apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release
  
  # Agregar llaves oficiales de Docker GPG
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  
  # Configurar repositorio de Docker
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
  apt update
  apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  
  # Habilitar e iniciar servicio Docker
  systemctl enable docker
  systemctl start docker
  echo -e "${GREEN}Docker instalado e iniciado con éxito.${NC}"
else
  echo -e "${GREEN}[2/6] Docker ya está instalado. Continuando...${NC}"
fi

# 4. Configurar variables de entorno
echo -e "${GREEN}[3/6] Configurando archivo de variables de entorno (.env)...${NC}"
if [ ! -f "../.env" ]; then
  if [ -f "../.env.example" ]; then
    cp ../.env.example ../.env
    echo -e "${GREEN}Archivo .env creado desde la plantilla .env.example.${NC}"
    echo -e "${BLUE}Por favor, edite el archivo .env si necesita cambiar contraseñas de producción.${NC}"
  else
    echo -e "${RED}Advertencia: No se encontró .env.example en el directorio padre. Creando archivo .env básico...${NC}"
    cat <<EOT > ../.env
POSTGRES_SERVER=db
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres_prod_pwd_d8
POSTGRES_DB=centinel8_db
POSTGRES_PORT=5432
SECRET_KEY=$(openssl rand -hex 32)
ACCESS_TOKEN_EXPIRE_MINUTES=10080
EOT
  fi
else
  echo -e "${GREEN}El archivo .env ya existe. Omitiendo creación.${NC}"
fi

# 5. Levantar contenedores Docker Compose
echo -e "${GREEN}[4/6] Levantando base de datos (PostgreSQL/PostGIS) y backend (FastAPI) con Docker Compose...${NC}"
cd ..
docker compose down || true
docker compose up --build -d

# 6. Esperar a que la base de datos esté lista
echo -e "${GREEN}[5/6] Esperando que la base de datos esté lista para recibir conexiones...${NC}"
until docker exec centinel8_db_container pg_isready -U postgres -d centinel8_db > /dev/null 2>&1; do
  echo -e "${BLUE}Esperando 3 segundos adicionales...${NC}"
  sleep 3
done

# 7. Ejecutar Migraciones Alembic y Sembrar Datos de Prueba
echo -e "${GREEN}[6/6] Poblando base de datos con usuarios y 65 incidentes históricos del Distrito 8...${NC}"
docker exec centinel8_backend_container python backend_seed.py

echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}¡Despliegue completado con éxito!${NC}"
echo -e "${BLUE}Servicio API Backend: http://localhost:8000${NC}"
echo -e "${BLUE}Documentación interactiva Swagger: http://localhost:8000/docs${NC}"
echo -e "${GREEN}================================================================${NC}"
