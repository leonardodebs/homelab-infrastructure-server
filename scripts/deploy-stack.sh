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

# O Caddyfile é bind mount de arquivo único; após um git pull que o altere, o
# container não recarrega sozinho (o inode antigo continua montado). Um restart
# barato garante que o Caddy sempre sirva a versão atual.
docker restart caddy >/dev/null 2>&1 || true

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps
