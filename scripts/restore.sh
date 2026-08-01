#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
  echo "Uso: $0 /opt/homelab/backups/AAAAMMDD-HHMMSS" >&2
  exit 1
fi

BACKUP_DIR="$1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/compose/.env"
COMPOSE_FILE="$ROOT_DIR/compose/compose.yaml"

[[ -d "$BACKUP_DIR" ]] || { echo "Backup não encontrado: $BACKUP_DIR" >&2; exit 1; }

read -r -p "A restauração substituirá os volumes atuais. Digite RESTAURAR: " CONFIRM
[[ "$CONFIRM" == "RESTAURAR" ]] || exit 1

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" down

for volume in portainer_data adguard_work adguard_conf uptime_kuma_data; do
  archive="$BACKUP_DIR/${volume}.tar.gz"
  [[ -f "$archive" ]] || { echo "Arquivo ausente: $archive" >&2; exit 1; }
  docker volume create "homelab_${volume}" >/dev/null
  docker run --rm \
    -v "homelab_${volume}:/target" \
    -v "$BACKUP_DIR:/backup:ro" \
    alpine:3.20 \
    sh -c "rm -rf /target/* /target/.[!.]* /target/..?* 2>/dev/null || true; tar xzf /backup/${volume}.tar.gz -C /target"
done

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d

echo "Restauração concluída. Valide os serviços e logs."
