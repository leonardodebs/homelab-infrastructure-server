#!/usr/bin/env bash
set -Eeuo pipefail

SERVER_IP="${SERVER_IP:-192.168.100.10}"

echo '== Host =='
hostnamectl --static
uptime
free -h
df -h /

echo '== Serviços =='
systemctl is-active docker
systemctl is-active unbound

echo '== Containers =='
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

echo '== Portas =='
sudo ss -lntup | grep -E ':22 |:53 |:80 |:3001 |:5335 |:9443 ' || true

echo '== DNS =='
dig +short @127.0.0.1 -p 5335 ubuntu.com
dig +short @"$SERVER_IP" ubuntu.com

echo '== Gateway =='
ping -c 2 192.168.100.1
