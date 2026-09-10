#!/bin/bash
# EC2 user data - VM de aplicación (Amazon Linux 2023)
# Instala Docker + compose plugin + git, clona MS2 en /opt/ms2, escribe el
# .env de producción y levanta docker-compose.prod.yml.
#
# Uso: pegar tal cual en el campo "User data" al lanzar la instancia,
# editando las variables de abajo antes de lanzar.
set -euo pipefail

# ---------------------------------------------------------------------------
# Variables a editar antes de lanzar la instancia
# ---------------------------------------------------------------------------
REPO_URL="https://github.com/sgcasas/MS2.git"
REPO_BRANCH="main"
APP_DIR="/opt/ms2"

DB_HOST="CAMBIAR_POR_IP_PRIVADA_O_DNS_DE_LA_VM_DB"
DB_PORT="5432"
DB_NAME="ms2_menu"
DB_USER="ms2_user"
DB_PASSWORD="CAMBIAR_ESTA_PASSWORD"

# URL pública por la que se accede a esta API (usada por Swagger/clientes)
PUBLIC_API_URL="CAMBIAR_POR_IP_PUBLICA_O_DNS_DE_ESTA_VM:8082"

# ---------------------------------------------------------------------------
# No editar debajo de esta línea
# ---------------------------------------------------------------------------
log() { echo "[user-data-app] $*"; }

# --- Docker + compose plugin + git ---
if ! command -v docker >/dev/null 2>&1; then
  log "Instalando Docker..."
  dnf install -y docker
fi

if ! docker compose version >/dev/null 2>&1; then
  log "Instalando docker-compose-plugin..."
  dnf install -y docker-compose-plugin
fi

if ! command -v git >/dev/null 2>&1; then
  log "Instalando git..."
  dnf install -y git
fi

systemctl enable --now docker

# --- Clonar / actualizar repo ---
if [ -d "${APP_DIR}/.git" ]; then
  log "Repo ya presente en ${APP_DIR}, actualizando..."
  git -C "${APP_DIR}" fetch origin "${REPO_BRANCH}"
  git -C "${APP_DIR}" checkout "${REPO_BRANCH}"
  git -C "${APP_DIR}" reset --hard "origin/${REPO_BRANCH}"
else
  log "Clonando ${REPO_URL} en ${APP_DIR}..."
  git clone --branch "${REPO_BRANCH}" "${REPO_URL}" "${APP_DIR}"
fi

# --- .env de producción ---
cat > "${APP_DIR}/.env" <<EOF
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
PUBLIC_API_URL=${PUBLIC_API_URL}
EOF
chmod 600 "${APP_DIR}/.env"

# --- Levantar stack (idempotente: up -d no duplica contenedores) ---
cd "${APP_DIR}"
docker compose -f docker-compose.prod.yml up -d --build

log "Listo. Ver estado con: docker compose -f ${APP_DIR}/docker-compose.prod.yml ps"
