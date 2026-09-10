#!/usr/bin/env bash
set -Eeuo pipefail

SERVER_IP="${SERVER_IP:-192.168.15.2}"
BACKUP_MOUNT="${BACKUP_MOUNT:-/srv/backup}"

echo '== Host =='
hostnamectl --static
uptime
free -h
df -h /

echo '== Serviços nativos =='
systemctl is-active docker
systemctl is-active unbound
systemctl is-active ntopng

echo '== Containers =='
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

echo '== Portas importantes =='
# públicas (Caddy) + internas reais + serviços de base
sudo ss -lntup | grep -E '(:22|:53|:67|:80|:443|:3000|:3001|:5335|:8080|:8280|:8443|:9443|:9444|:9899|:3300|:3101|:8180)\b' || true

echo '== Caddy (TLS local) =='
docker exec caddy caddy validate --config /etc/caddy/Caddyfile 2>&1 | tail -1 || true
curl -sk -o /dev/null -w 'portainer.home.arpa -> HTTP %{http_code}\n' \
  --resolve portainer.home.arpa:443:"$SERVER_IP" https://portainer.home.arpa/ || true

echo '== DNS =='
dig +short @127.0.0.1 -p 5335 ubuntu.com
dig +short @"$SERVER_IP" ubuntu.com
for h in adguard portainer kuma web ntop backrest; do
  printf '%s.home.arpa -> ' "$h"
  dig +short @"$SERVER_IP" "$h.home.arpa"
done

echo '== Gateway =='
ping -c 2 192.168.15.1

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
