#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/compose/.env"
COMPOSE_FILE="$ROOT_DIR/compose/compose.yaml"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Arquivo compose/.env não encontrado." >&2
  exit 1
fi

"$ROOT_DIR/scripts/backup.sh"

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" pull
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d --remove-orphans
docker image prune -f

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps
