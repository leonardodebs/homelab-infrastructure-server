#!/usr/bin/env bash
set -Eeuo pipefail

MOUNT_POINT="${BACKUP_MOUNT:-/srv/backup}"

fail() {
  echo "ERRO: $*" >&2
  exit 1
}

[[ $EUID -eq 0 ]] || fail "Execute como root."
mountpoint -q "$MOUNT_POINT" || fail "$MOUNT_POINT não está montado."

SOURCE="$(findmnt -n -o SOURCE "$MOUNT_POINT")"
PARENT="$(lsblk -ndo PKNAME "$SOURCE" 2>/dev/null | head -n1 || true)"

if [[ -n "$PARENT" ]]; then
  DEVICE="/dev/$PARENT"
else
  DEVICE="$SOURCE"
fi

[[ -b "$DEVICE" ]] || fail "Não foi possível identificar o disco físico de $SOURCE."

echo "Disco de backup: $DEVICE"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,MODEL,SERIAL "$DEVICE"

echo
if smartctl -H -A "$DEVICE"; then
  exit 0
fi

echo "Leitura padrão falhou; tentando protocolo SAT da ponte USB..."
smartctl -d sat -H -A "$DEVICE"
