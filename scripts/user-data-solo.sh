#!/bin/bash
# EC2 user data - VM ÚNICA y temporal (Amazon Linux 2023)
# Levanta Postgres + la app JUNTOS en la misma instancia usando el
# docker-compose.yml normal (NO docker-compose.prod.yml, NO DB_HOST),
# para exponer el MS2 rápido mientras se arma la arquitectura completa
# (VM de app + VM de db separadas, ver user-data-app.sh / user-data-db.sh).
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

DB_USER="postgres"
DB_PASSWORD="CAMBIAR_ESTA_PASSWORD"

SWAP_FILE="/swapfile"
SWAP_SIZE_MB=2048

HEALTH_URL="http://localhost:8082/actuator/health"
HEALTH_TIMEOUT_SECONDS=600
LOG_FILE="/var/log/ms2-bootstrap.log"

# ---------------------------------------------------------------------------
# No editar debajo de esta línea
# ---------------------------------------------------------------------------
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [user-data-solo] $*" | tee -a "${LOG_FILE}"; }

touch "${LOG_FILE}"
log "Iniciando bootstrap de VM única (db + app)..."

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

# --- Swap (antes del build: Maven se queda sin memoria en instancias chicas) ---
if [ -f "${SWAP_FILE}" ]; then
  log "Swapfile ${SWAP_FILE} ya existe, se omite creación."
else
  log "Creando swap de ${SWAP_SIZE_MB}MB en ${SWAP_FILE}..."
  dd if=/dev/zero of="${SWAP_FILE}" bs=1M count="${SWAP_SIZE_MB}"
  chmod 600 "${SWAP_FILE}"
  mkswap "${SWAP_FILE}"
fi

if ! swapon --show=NAME --noheadings | grep -qx "${SWAP_FILE}"; then
  swapon "${SWAP_FILE}"
fi

if ! grep -qF "${SWAP_FILE}" /etc/fstab; then
  log "Agregando swap a /etc/fstab..."
  echo "${SWAP_FILE} none swap sw 0 0" >> /etc/fstab
fi

# --- Clonar / actualizar repo ---
if [ -d "${APP_DIR}/.git" ]; then
  log "Repo ya presente en ${APP_DIR}, actualizando (git pull)..."
  git -C "${APP_DIR}" fetch origin "${REPO_BRANCH}"
  git -C "${APP_DIR}" checkout "${REPO_BRANCH}"
  git -C "${APP_DIR}" pull origin "${REPO_BRANCH}"
else
  log "Clonando ${REPO_URL} en ${APP_DIR}..."
  git clone --branch "${REPO_BRANCH}" "${REPO_URL}" "${APP_DIR}"
fi

# --- .env local (docker-compose.yml normal: db + app en la misma stack) ---
cat > "${APP_DIR}/.env" <<EOF
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
EOF
chmod 600 "${APP_DIR}/.env"

# --- Levantar stack (idempotente: up -d no duplica contenedores) ---
cd "${APP_DIR}"
log "Levantando docker compose (up -d --build)..."
docker compose up -d --build

# --- Esperar a que /actuator/health responda UP ---
log "Esperando a que ${HEALTH_URL} responda UP (timeout ${HEALTH_TIMEOUT_SECONDS}s)..."
elapsed=0
interval=5
status="DOWN_OR_UNREACHABLE"
while [ "${elapsed}" -lt "${HEALTH_TIMEOUT_SECONDS}" ]; do
  body="$(curl -fsS "${HEALTH_URL}" 2>/dev/null || true)"
  if echo "${body}" | grep -q '"status":"UP"'; then
    status="UP"
    break
  fi
  sleep "${interval}"
  elapsed=$((elapsed + interval))
done

if [ "${status}" = "UP" ]; then
  log "MS2 arriba y saludable (health=UP) tras ${elapsed}s."
else
  log "TIMEOUT: MS2 no respondió UP en ${HEALTH_TIMEOUT_SECONDS}s. Último body: ${body:-<sin respuesta>}"
  docker compose ps >> "${LOG_FILE}" 2>&1
  docker compose logs --tail=100 >> "${LOG_FILE}" 2>&1
  exit 1
fi

log "Listo. Ver estado con: docker compose -f ${APP_DIR}/docker-compose.yml ps"
