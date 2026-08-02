#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_DIR="/etc/homelab-backup"
MOUNT_POINT="/srv/backup"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "ERRO: $*" >&2
  exit 1
}

[[ $EUID -eq 0 ]] || fail "Execute com sudo."
mountpoint -q "$MOUNT_POINT" || fail "$MOUNT_POINT não está montado. Execute prepare-backup-disk.sh primeiro."

FSTYPE="$(findmnt -n -o FSTYPE "$MOUNT_POINT")"
[[ "$FSTYPE" == "ext4" ]] || fail "Sistema de arquivos inesperado em $MOUNT_POINT: $FSTYPE. O projeto foi desenhado para ext4."

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y restic smartmontools python3 util-linux

install -d -m 0700 "$CONFIG_DIR"
install -d -m 0700 /var/cache/restic-homelab /var/lib/homelab-backup
install -d -m 0750 "$MOUNT_POINT/restic" "$MOUNT_POINT/restore-tests" "$MOUNT_POINT/status"
install -m 0600 "$ROOT_DIR/config/restic/excludes.txt" "$CONFIG_DIR/excludes.txt"

cat >"$CONFIG_DIR/restic.env" <<EOF
RESTIC_REPOSITORY=$MOUNT_POINT/restic
RESTIC_PASSWORD_FILE=$CONFIG_DIR/restic-password
RESTIC_CACHE_DIR=/var/cache/restic-homelab
HOMELAB_PROJECT_DIR=$ROOT_DIR
BACKUP_MOUNT=$MOUNT_POINT
EOF
chmod 0600 "$CONFIG_DIR/restic.env"

if [[ ! -f "$CONFIG_DIR/restic-password" ]]; then
  echo "Crie uma senha forte para criptografar o repositório Restic."
  echo "Guarde essa senha fora do servidor. Sem ela, a restauração será impossível."
  while true; do
    read -r -s -p "Senha Restic (mínimo 16 caracteres): " PASSWORD
    echo
    read -r -s -p "Confirme a senha: " PASSWORD_CONFIRM
    echo

    if [[ ${#PASSWORD} -lt 16 ]]; then
      echo "A senha precisa ter pelo menos 16 caracteres."
      continue
    fi
    if [[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]]; then
      echo "As senhas não coincidem."
      continue
    fi
    break
  done

  umask 077
  printf '%s\n' "$PASSWORD" >"$CONFIG_DIR/restic-password"
  unset PASSWORD PASSWORD_CONFIRM
fi
chmod 0600 "$CONFIG_DIR/restic-password"

install -m 0750 "$ROOT_DIR/scripts/restic-backup.sh" /usr/local/sbin/homelab-restic-backup
install -m 0750 "$ROOT_DIR/scripts/restic-maintenance.sh" /usr/local/sbin/homelab-restic-maintenance
install -m 0750 "$ROOT_DIR/scripts/restic-restore-test.sh" /usr/local/sbin/homelab-restic-restore-test
install -m 0750 "$ROOT_DIR/scripts/smart-check.sh" /usr/local/sbin/homelab-smart-check

install -m 0644 "$ROOT_DIR/systemd/homelab-backup.service" /etc/systemd/system/homelab-backup.service
install -m 0644 "$ROOT_DIR/systemd/homelab-backup.timer" /etc/systemd/system/homelab-backup.timer
install -m 0644 "$ROOT_DIR/systemd/homelab-backup-maintenance.service" /etc/systemd/system/homelab-backup-maintenance.service
install -m 0644 "$ROOT_DIR/systemd/homelab-backup-maintenance.timer" /etc/systemd/system/homelab-backup-maintenance.timer
install -m 0644 "$ROOT_DIR/systemd/homelab-restore-test.service" /etc/systemd/system/homelab-restore-test.service
install -m 0644 "$ROOT_DIR/systemd/homelab-restore-test.timer" /etc/systemd/system/homelab-restore-test.timer

set -a
# shellcheck disable=SC1091
source "$CONFIG_DIR/restic.env"
set +a

if [[ ! -f "$RESTIC_REPOSITORY/config" ]]; then
  restic init
else
  echo "Repositório Restic já inicializado em $RESTIC_REPOSITORY."
  restic snapshots >/dev/null
fi

systemctl daemon-reload
systemctl enable --now homelab-backup.timer
systemctl enable --now homelab-backup-maintenance.timer
systemctl enable --now homelab-restore-test.timer

echo
echo "Stack de backup instalada."
echo "Execute o primeiro backup agora com:"
echo "  sudo systemctl start homelab-backup.service"
echo
echo "Acompanhe com:"
echo "  sudo journalctl -u homelab-backup.service -f"
echo "  systemctl list-timers 'homelab-*'"
