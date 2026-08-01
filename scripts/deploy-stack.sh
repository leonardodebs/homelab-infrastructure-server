#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/compose/.env"
COMPOSE_FILE="$ROOT_DIR/compose/compose.yaml"

if [[ ! -f "$ENV_FILE" ]]; then
  cp "$ROOT_DIR/compose/.env.example" "$ENV_FILE"
  echo "Arquivo $ENV_FILE criado. Revise SERVER_IP e execute novamente." >&2
  exit 1
fi

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" config >/dev/null
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" pull
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps
