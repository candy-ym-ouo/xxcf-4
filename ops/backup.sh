#!/usr/bin/env sh
set -eu

PROJECT_NAME="${COMPOSE_PROJECT_NAME:-handcraft-material-tracker}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
TARGET="${BACKUP_DIR}/${TIMESTAMP}"
POSTGRES_CONTAINER="$(docker compose -p "${PROJECT_NAME}" ps -aq postgres)"
API_CONTAINER="$(docker compose -p "${PROJECT_NAME}" ps -aq api)"
RUNNING_SERVICES="$(docker compose -p "${PROJECT_NAME}" ps --status running --services 2>/dev/null || true)"
RESTART_SERVICES=""

if printf '%s\n' "${RUNNING_SERVICES}" | grep -qx "api"; then
  RESTART_SERVICES="${RESTART_SERVICES} api"
fi
if printf '%s\n' "${RUNNING_SERVICES}" | grep -qx "web"; then
  RESTART_SERVICES="${RESTART_SERVICES} web"
fi

restore_services() {
  if [ -n "${RESTART_SERVICES}" ]; then
    docker compose -p "${PROJECT_NAME}" start ${RESTART_SERVICES} >/dev/null
  fi
}

cleanup() {
  restore_services || true
}

if [ -n "${RESTART_SERVICES}" ]; then
  trap cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  echo "Stopping application writers for a consistent backup..."
  docker compose -p "${PROJECT_NAME}" stop ${RESTART_SERVICES} >/dev/null
fi

mkdir -p "${TARGET}"
if [ -z "${POSTGRES_CONTAINER}" ] || [ -z "${API_CONTAINER}" ]; then
  echo "PostgreSQL or API container is missing" >&2
  exit 1
fi

UPLOADS_VOLUME="$(docker inspect "${API_CONTAINER}" --format '{{range .Mounts}}{{if eq .Destination "/app/uploads"}}{{.Name}}{{end}}{{end}}')"
if [ -z "${UPLOADS_VOLUME}" ]; then
  echo "Uploads volume is not mounted at /app/uploads" >&2
  exit 1
fi

docker exec "${POSTGRES_CONTAINER}" sh -c \
  'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --format=custom --no-owner' < /dev/null > "${TARGET}/database.dump"
docker run --rm -v "${UPLOADS_VOLUME}:/data" node:22 tar -C /data -czf - . < /dev/null > "${TARGET}/attachments.tar.gz"

if command -v shasum >/dev/null 2>&1; then
  (cd "${TARGET}" && shasum -a 256 database.dump attachments.tar.gz > SHA256SUMS)
else
  (cd "${TARGET}" && sha256sum database.dump attachments.tar.gz > SHA256SUMS)
fi

if [ -n "${RESTART_SERVICES}" ]; then
  trap - EXIT INT TERM
  restore_services
fi

echo "Backup created at ${TARGET}"
