#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Execute com sudo: sudo $0" >&2
  exit 1
fi

apt update
apt full-upgrade -y
apt install -y ca-certificates curl wget git nano vim htop btop jq unzip tree \
  dnsutils net-tools ufw smartmontools apache2-utils unattended-upgrades \
  unbound unbound-anchor dns-root-data

timedatectl set-timezone America/Sao_Paulo
hostnamectl set-hostname homelab

# A stack Compose roda direto do clone em ~/homelab-infrastructure-server;
# não há diretório operacional em /opt.

mkdir -p /etc/systemd/journald.conf.d
cat >/etc/systemd/journald.conf.d/size.conf <<'EOF'
[Journal]
SystemMaxUse=200M
RuntimeMaxUse=100M
MaxRetentionSec=7day
EOF
systemctl restart systemd-journald

ufw default deny incoming
ufw default allow outgoing
ufw allow from 192.168.15.0/24 to any port 22 proto tcp comment 'SSH LAN'
ufw --force enable

echo "Bootstrap concluído para o host homelab. Configure o IP estático antes de continuar."
