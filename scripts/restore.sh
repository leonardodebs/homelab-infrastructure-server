#!/usr/bin/env bash
set -Eeuo pipefail

ENV_FILE="/etc/homelab-backup/restic.env"
SNAPSHOT="${1:-latest}"
STAMP="$(date +%Y%m%d-%H%M%S)"
TARGET="${2:-/srv/backup/manual-restore/$STAMP}"

fail() {
  echo "ERRO: $*" >&2
  exit 1
}

[[ $EUID -eq 0 ]] || fail "Execute com sudo."
[[ -r "$ENV_FILE" ]] || fail "Arquivo ausente: $ENV_FILE"

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${RESTIC_REPOSITORY:?RESTIC_REPOSITORY não definido}"
: "${RESTIC_PASSWORD_FILE:?RESTIC_PASSWORD_FILE não definido}"
: "${BACKUP_MOUNT:=/srv/backup}"

mountpoint -q "$BACKUP_MOUNT" || fail "$BACKUP_MOUNT não está montado."

HOST_TAG="$(hostname --short)"
echo "Snapshot: $SNAPSHOT"
echo "Destino:  $TARGET"
echo "A restauração será feita em uma pasta separada e não substituirá os dados ativos."
read -r -p "Digite RESTAURAR $SNAPSHOT para continuar: " CONFIRM
[[ "$CONFIRM" == "RESTAURAR $SNAPSHOT" ]] || fail "Operação cancelada."

mkdir -p "$TARGET"
restic restore "$SNAPSHOT" --host "$HOST_TAG" --tag homelab --target "$TARGET"

FILE_COUNT="$(find "$TARGET" -type f | wc -l)"
echo "Restauração concluída em $TARGET"
echo "Arquivos restaurados: $FILE_COUNT"
echo "Revise os dados antes de copiar qualquer conteúdo para o ambiente ativo."
