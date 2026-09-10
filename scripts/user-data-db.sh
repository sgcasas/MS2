#!/bin/bash
# EC2 user data - VM de base de datos (Amazon Linux 2023)
# Instala Docker y levanta postgres:16-alpine con volumen persistente.
#
# Uso: pegar tal cual en el campo "User data" al lanzar la instancia,
# editando las variables de abajo antes de lanzar.
set -euo pipefail

# ---------------------------------------------------------------------------
# Variables a editar antes de lanzar la instancia
# ---------------------------------------------------------------------------
DB_NAME="ms2_menu"
DB_USER="ms2_user"
DB_PASSWORD="CAMBIAR_ESTA_PASSWORD"
DB_PORT="5432"

# ---------------------------------------------------------------------------
# No editar debajo de esta línea
# ---------------------------------------------------------------------------
CONTAINER_NAME="ms2-db"
VOLUME_NAME="ms2_menu_pgdata"
IMAGE="postgres:16-alpine"

log() { echo "[user-data-db] $*"; }

# --- Docker ---
if ! command -v docker >/dev/null 2>&1; then
  log "Instalando Docker..."
  dnf install -y docker
fi

systemctl enable --now docker

# Volumen persistente (idempotente: no falla si ya existe)
docker volume create "${VOLUME_NAME}" >/dev/null

# Contenedor fijo, idempotente frente a reejecuciones del script
if docker ps -a --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
  log "Contenedor ${CONTAINER_NAME} ya existe, asegurando que esté corriendo..."
  docker start "${CONTAINER_NAME}" >/dev/null 2>&1 || true
else
  log "Creando contenedor ${CONTAINER_NAME}..."
  docker run -d \
    --name "${CONTAINER_NAME}" \
    --restart=always \
    -e POSTGRES_DB="${DB_NAME}" \
    -e POSTGRES_USER="${DB_USER}" \
    -e POSTGRES_PASSWORD="${DB_PASSWORD}" \
    -v "${VOLUME_NAME}:/var/lib/postgresql/data" \
    -p "${DB_PORT}:5432" \
    "${IMAGE}"
fi

log "Listo. postgres escuchando en el puerto ${DB_PORT}."
