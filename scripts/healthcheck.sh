#!/usr/bin/env bash
set -Eeuo pipefail

SERVER_IP="${SERVER_IP:-192.168.100.2}"
BACKUP_MOUNT="${BACKUP_MOUNT:-/srv/backup}"

echo '== Host =='
hostnamectl --static
uptime
free -h
df -h /

echo '== Serviços nativos =='
systemctl is-active docker
systemctl is-active unbound

echo '== Containers =='
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

echo '== Portas importantes =='
sudo ss -lntup | grep -E '(:22|:53|:67|:80|:3001|:5335|:8080|:8090|:9443)\b' || true

echo '== DNS =='
dig +short @127.0.0.1 -p 5335 ubuntu.com
dig +short @"$SERVER_IP" ubuntu.com

echo '== Gateway =='
ping -c 2 192.168.100.1

echo '== Rede Docker =='
docker network inspect homelab_default \
  --format '{{range .IPAM.Config}}Subnet={{.Subnet}} Gateway={{.Gateway}}{{end}}' 2>/dev/null || true

echo '== Backup externo =='
if mountpoint -q "$BACKUP_MOUNT"; then
  findmnt "$BACKUP_MOUNT"
  df -h "$BACKUP_MOUNT"
  if [[ -r "$BACKUP_MOUNT/status/last-success.txt" ]]; then
    echo '-- Último backup bem-sucedido --'
    cat "$BACKUP_MOUNT/status/last-success.txt"
  else
    echo 'Ainda não há marcador de backup bem-sucedido.'
  fi
else
  echo "ALERTA: $BACKUP_MOUNT não está montado."
fi

echo '== Timers HomeLab =='
systemctl list-timers 'homelab-*' --no-pager || true

echo '== Serviços com falha =='
systemctl --failed --no-pager || true
