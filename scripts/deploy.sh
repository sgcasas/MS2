#!/bin/bash
# Deploy manual por SSH en la VM de app: git pull + docker compose up -d --build.
# Correr desde /opt/ms2 (o pasar el path como $1).
set -euo pipefail

APP_DIR="${1:-/opt/ms2}"
COMPOSE_FILE="docker-compose.prod.yml"

cd "${APP_DIR}"

echo "[deploy] git pull en ${APP_DIR}..."
git pull

echo "[deploy] docker compose up -d --build..."
docker compose -f "${COMPOSE_FILE}" up -d --build

echo "[deploy] últimas 50 líneas de logs:"
docker compose -f "${COMPOSE_FILE}" logs --tail=50
