#!/usr/bin/env bash
set -Eeuo pipefail

ENV_FILE="/etc/homelab-backup/restic.env"
LOCK_FILE="/run/lock/homelab-restic.lock"

fail() {
  echo "ERRO: $*" >&2
  exit 1
}

[[ $EUID -eq 0 ]] || fail "Execute como root."
[[ -r "$ENV_FILE" ]] || fail "Arquivo ausente: $ENV_FILE"

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${RESTIC_REPOSITORY:?RESTIC_REPOSITORY não definido}"
: "${RESTIC_PASSWORD_FILE:?RESTIC_PASSWORD_FILE não definido}"
: "${BACKUP_MOUNT:=/srv/backup}"

mountpoint -q "$BACKUP_MOUNT" || fail "$BACKUP_MOUNT não está montado."

exec 9>"$LOCK_FILE"
flock -n 9 || fail "Outra operação Restic está em execução."

HOST_TAG="$(hostname --short)"

echo "Aplicando retenção e liberando espaço não referenciado..."
nice -n 15 ionice -c2 -n7 restic forget \
  --host "$HOST_TAG" \
  --tag homelab \
  --keep-daily 7 \
  --keep-weekly 8 \
  --keep-monthly 12 \
  --keep-yearly 2 \
  --prune

echo "Validando metadados e 10% dos dados do repositório..."
nice -n 15 ionice -c2 -n7 restic check --read-data-subset=10%

if command -v homelab-smart-check >/dev/null 2>&1; then
  homelab-smart-check || echo "AVISO: a leitura SMART não foi concluída; verifique a ponte USB."
fi

df -h "$BACKUP_MOUNT"
restic stats --mode restore-size

echo "Manutenção do backup concluída."
