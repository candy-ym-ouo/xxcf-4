#!/usr/bin/env sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 /absolute/path/to/backup-directory" >&2
  exit 1
fi

BACKUP_PATH="$1"
PROJECT_NAME="${COMPOSE_PROJECT_NAME:-handcraft-material-tracker}"
POSTGRES_CONTAINER="$(docker compose -p "${PROJECT_NAME}" ps -aq postgres)"
API_CONTAINER="$(docker compose -p "${PROJECT_NAME}" ps -aq api)"

if [ -z "${POSTGRES_CONTAINER}" ] || [ -z "${API_CONTAINER}" ]; then
  echo "PostgreSQL or API container is missing" >&2
  exit 1
fi

UPLOADS_VOLUME="$(docker inspect "${API_CONTAINER}" --format '{{range .Mounts}}{{if eq .Destination "/app/uploads"}}{{.Name}}{{end}}{{end}}')"
if [ -z "${UPLOADS_VOLUME}" ]; then
  echo "Uploads volume is not mounted at /app/uploads" >&2
  exit 1
fi

if [ ! -f "${BACKUP_PATH}/database.dump" ] || [ ! -f "${BACKUP_PATH}/attachments.tar.gz" ]; then
  echo "Backup directory must contain database.dump and attachments.tar.gz" >&2
  exit 1
fi

if [ -f "${BACKUP_PATH}/SHA256SUMS" ]; then
  if command -v shasum >/dev/null 2>&1; then
    (cd "${BACKUP_PATH}" && shasum -a 256 -c SHA256SUMS)
  else
    (cd "${BACKUP_PATH}" && sha256sum -c SHA256SUMS)
  fi
fi

docker exec -i "${POSTGRES_CONTAINER}" pg_restore --list < "${BACKUP_PATH}/database.dump" >/dev/null
docker run --rm -i -v "${UPLOADS_VOLUME}:/data" node:22 tar -C /data -tzf - < "${BACKUP_PATH}/attachments.tar.gz" >/dev/null

echo "Stopping application writers..."
docker compose -p "${PROJECT_NAME}" stop web api

echo "Restoring PostgreSQL..."
docker exec "${POSTGRES_CONTAINER}" sh -c \
  'dropdb -U "$POSTGRES_USER" --if-exists "$POSTGRES_DB" && createdb -U "$POSTGRES_USER" "$POSTGRES_DB"' < /dev/null
docker exec -i "${POSTGRES_CONTAINER}" sh -c \
  'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists --no-owner' < "${BACKUP_PATH}/database.dump"

echo "Restoring attachments..."
docker run --rm -v "${UPLOADS_VOLUME}:/data" node:22 sh -c 'find /data -mindepth 1 -delete' < /dev/null
docker run --rm -i -v "${UPLOADS_VOLUME}:/data" node:22 tar -C /data -xzf - < "${BACKUP_PATH}/attachments.tar.gz"

echo "Starting application services..."
docker compose -p "${PROJECT_NAME}" up -d
echo "Restore complete."
