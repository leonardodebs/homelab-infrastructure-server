#!/usr/bin/env bash
set -Eeuo pipefail

MOUNT_POINT="${BACKUP_MOUNT:-/srv/backup}"

fail() {
  echo "ERRO: $*" >&2
  exit 1
}

[[ $EUID -eq 0 ]] || fail "Execute como root."
mountpoint -q "$MOUNT_POINT" || fail "$MOUNT_POINT não está montado."

# "findmnt -o SOURCE" pode retornar o gatilho autofs (ex.: "systemd-1")
# em vez do device real quando o ponto de montagem é gerenciado por
# systemd automount. "df --output=source" resolve o filesystem
# efetivamente montado e não sofre desse problema.
SOURCE="$(df --output=source "$MOUNT_POINT" | tail -n1)"
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
if smartctl -d sat -H -A "$DEVICE"; then
  exit 0
fi

echo "SAT falhou; tentando protocolo SCSI genérico da ponte USB..."
smartctl -d scsi -H -A "$DEVICE"
