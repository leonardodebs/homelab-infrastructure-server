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

STAMP="$(date +%Y%m%d-%H%M%S)"
TARGET="$BACKUP_MOUNT/restore-tests/$STAMP"
mkdir -p "$TARGET"

HOST_TAG="$(hostname --short)"
echo "Restaurando o snapshot mais recente em $TARGET"
restic restore latest --host "$HOST_TAG" --tag homelab --target "$TARGET"

FILE_COUNT="$(find "$TARGET" -type f | wc -l)"
[[ "$FILE_COUNT" -gt 0 ]] || fail "O teste não restaurou nenhum arquivo."

cat >"$TARGET/RESTORE_TEST_OK.txt" <<EOF
status=success
finished_at=$(date --iso-8601=seconds)
files_restored=$FILE_COUNT
snapshot=latest
EOF

find "$BACKUP_MOUNT/restore-tests" -mindepth 1 -maxdepth 1 -type d -mtime +35 -exec rm -rf {} +
sync

echo "Teste de restauração concluído: $FILE_COUNT arquivos restaurados."
