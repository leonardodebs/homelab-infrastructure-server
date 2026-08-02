#!/usr/bin/env bash
set -Eeuo pipefail

MOUNT_POINT="/srv/backup"
LABEL="HOMELAB_BACKUP"

fail() {
  echo "ERRO: $*" >&2
  exit 1
}

[[ $EUID -eq 0 ]] || fail "Execute com sudo."
[[ $# -eq 1 ]] || fail "Uso: sudo $0 /dev/sdX"

DEVICE="$(readlink -f "$1")"
[[ -b "$DEVICE" ]] || fail "Dispositivo inexistente: $DEVICE"
[[ "$(lsblk -dn -o TYPE "$DEVICE")" == "disk" ]] || fail "Informe o disco inteiro, por exemplo /dev/sdb, e não uma partição."

ROOT_SOURCE="$(findmnt -n -o SOURCE / || true)"
ROOT_DISK=""
if [[ -n "$ROOT_SOURCE" ]]; then
  ROOT_PARENT="$(lsblk -ndo PKNAME "$ROOT_SOURCE" 2>/dev/null | head -n1 || true)"
  [[ -n "$ROOT_PARENT" ]] && ROOT_DISK="/dev/$ROOT_PARENT"
fi

if [[ "$DEVICE" == "$ROOT_SOURCE" || "$DEVICE" == "$ROOT_DISK" ]]; then
  fail "Recusando apagar o disco que contém o sistema operacional: $DEVICE"
fi

if lsblk -nrpo MOUNTPOINT "$DEVICE" | grep -qE '^/'; then
  echo "Partições montadas encontradas:"
  lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,MODEL,SERIAL "$DEVICE"
  fail "Desmonte todas as partições deste disco antes de continuar."
fi

echo "ATENÇÃO: este procedimento APAGA TODO O CONTEÚDO do disco abaixo."
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,MODEL,SERIAL "$DEVICE"
echo
read -r -p "Para confirmar, digite exatamente: APAGAR $DEVICE: " CONFIRM
[[ "$CONFIRM" == "APAGAR $DEVICE" ]] || fail "Operação cancelada."

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y parted e2fsprogs util-linux

wipefs --all --force "$DEVICE"
parted --script "$DEVICE" mklabel gpt
parted --script "$DEVICE" mkpart primary ext4 1MiB 100%
partprobe "$DEVICE"
udevadm settle

BASE="$(basename "$DEVICE")"
if [[ "$BASE" =~ [0-9]$ ]]; then
  PARTITION="${DEVICE}p1"
else
  PARTITION="${DEVICE}1"
fi

for _ in {1..20}; do
  [[ -b "$PARTITION" ]] && break
  sleep 1
done
[[ -b "$PARTITION" ]] || fail "A partição $PARTITION não apareceu após o particionamento."

mkfs.ext4 -F -m 1 -L "$LABEL" "$PARTITION"
UUID="$(blkid -s UUID -o value "$PARTITION")"
[[ -n "$UUID" ]] || fail "Não foi possível obter o UUID da partição."

mkdir -p "$MOUNT_POINT"
FSTAB_LINE="UUID=$UUID $MOUNT_POINT ext4 defaults,nofail,x-systemd.automount,x-systemd.device-timeout=10s 0 2"

if ! grep -qE "^[^#].*[[:space:]]${MOUNT_POINT//\//\\/}[[:space:]]" /etc/fstab; then
  printf '\n# HD externo dedicado aos backups do HomeLab\n%s\n' "$FSTAB_LINE" >> /etc/fstab
else
  echo "AVISO: já existe uma entrada para $MOUNT_POINT em /etc/fstab. Revise-a manualmente."
fi

systemctl daemon-reload
mount "$MOUNT_POINT"
chown root:root "$MOUNT_POINT"
chmod 0750 "$MOUNT_POINT"
mkdir -p "$MOUNT_POINT/restic" "$MOUNT_POINT/restore-tests" "$MOUNT_POINT/status"
chmod 0750 "$MOUNT_POINT/restic" "$MOUNT_POINT/restore-tests" "$MOUNT_POINT/status"

sync

echo
echo "HD preparado com sucesso."
echo "Dispositivo: $PARTITION"
echo "UUID:        $UUID"
echo "Montagem:    $MOUNT_POINT"
findmnt "$MOUNT_POINT"
df -h "$MOUNT_POINT"
