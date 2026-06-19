#!/bin/bash
set -e

# Asegurar que se ejecuta como el usuario postgres
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS postgis;
EOSQL

# Ejecutar el archivo init.sql para crear tablas e insertar datos iniciales
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f /docker-entrypoint-initdb.d/init.sql
