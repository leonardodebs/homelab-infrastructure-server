#!/usr/bin/env bash
set -Eeuo pipefail

# HomeLab - Configuração segura do UFW
# Rede LAN: 192.168.100.0/24
# Interface LAN: enxd037454bc6c1
# Servidor: 192.168.100.2
#
# Regras:
# 22/tcp   SSH
# 53/tcp   DNS
# 53/udp   DNS
# 67/udp   DHCP Server (somente na interface LAN)
# 80/tcp   AdGuard Home
# 3001/tcp Uptime Kuma
# 8090/tcp Beszel
# 9443/tcp Portainer

LAN_CIDR="192.168.100.0/24"
LAN_IF="enxd037454bc6c1"
SERVER_IP="192.168.100.2"

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[AVISO]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[ERRO]\033[0m %s\n' "$*" >&2; exit 1; }

if [[ $EUID -ne 0 ]]; then
  die "Execute com sudo: sudo bash $0"
fi

log "Etapa 1/8 - Pré-validações"

command -v ufw >/dev/null 2>&1 || die "UFW não está instalado."
ip link show "$LAN_IF" >/dev/null 2>&1 || die "Interface $LAN_IF não existe."
ip -4 addr show dev "$LAN_IF" | grep -q "$SERVER_IP/" \
  || die "O IP $SERVER_IP não foi encontrado na interface $LAN_IF."

IPV6_VALUE="$(awk -F= '/^IPV6=/{print $2}' /etc/default/ufw 2>/dev/null || true)"
if [[ "$IPV6_VALUE" != "yes" ]]; then
  die "Esperado IPV6=yes em /etc/default/ufw. Valor atual: ${IPV6_VALUE:-não encontrado}"
fi

ok "Interface LAN: $LAN_IF"
ok "IP do servidor: $SERVER_IP"
ok "Rede autorizada: $LAN_CIDR"
ok "UFW com IPv6 habilitado"

if [[ -n "${SSH_CONNECTION:-}" ]]; then
  SSH_CLIENT_IP="$(awk '{print $1}' <<< "$SSH_CONNECTION")"
  warn "Sessão SSH detectada a partir de: $SSH_CLIENT_IP"
  warn "Mantenha esta sessão SSH aberta até validar uma segunda conexão."
fi

log "Etapa 2/8 - Estado atual do UFW"
ufw status verbose || true

log "Etapa 3/8 - Aplicando política padrão"
ufw default deny incoming
ufw default allow outgoing
ok "Entrada padrão: DENY"
ok "Saída padrão: ALLOW"

log "Etapa 4/8 - Liberando SSH PRIMEIRO"
ufw allow from "$LAN_CIDR" to any port 22 proto tcp comment 'SSH LAN'
ok "SSH TCP/22 permitido somente para $LAN_CIDR"

log "Etapa 5/8 - Liberando DNS e DHCP"
ufw allow from "$LAN_CIDR" to any port 53 proto tcp comment 'DNS TCP LAN'
ufw allow from "$LAN_CIDR" to any port 53 proto udp comment 'DNS UDP LAN'
ufw allow in on "$LAN_IF" to any port 67 proto udp comment 'DHCP server LAN'
ok "DNS TCP/UDP 53 permitido para a LAN"
ok "DHCP UDP/67 permitido somente pela interface $LAN_IF"

log "Etapa 6/8 - Liberando dashboards administrativos"
ufw allow from "$LAN_CIDR" to any port 80 proto tcp comment 'AdGuard Web LAN'
ufw allow from "$LAN_CIDR" to any port 3001 proto tcp comment 'Uptime Kuma LAN'
ufw allow from "$LAN_CIDR" to any port 8090 proto tcp comment 'Beszel LAN'
ufw allow from "$LAN_CIDR" to any port 9443 proto tcp comment 'Portainer LAN'
ok "AdGuard Web TCP/80"
ok "Uptime Kuma TCP/3001"
ok "Beszel TCP/8090"
ok "Portainer TCP/9443"

log "Etapa 7/8 - Revisão ANTES da ativação"
ufw show added

echo
read -r -p "Ativar o UFW agora? Digite SIM para continuar: " CONFIRM
if [[ "$CONFIRM" != "SIM" ]]; then
  warn "UFW NÃO foi ativado. As regras foram adicionadas, mas o firewall permanece no estado atual."
  exit 0
fi

log "Etapa 8/8 - Ativando e validando"
ufw --force enable

echo
ufw status numbered
echo
ufw status verbose

ok "UFW ativado."

log "Sockets importantes atualmente em escuta"
ss -lntup | grep -E '(:22|:53|:67|:80|:3001|:8090|:9443|:5335)\b' || true

cat <<'EOT'

============================================================
PRÓXIMA VALIDAÇÃO - NÃO FECHE ESTA SESSÃO SSH AINDA
============================================================

Em OUTRO PowerShell no Windows, teste:

  ssh leonardo@192.168.100.2

  Test-NetConnection 192.168.100.2 -Port 22
  Test-NetConnection 192.168.100.2 -Port 80
  Test-NetConnection 192.168.100.2 -Port 3001
  Test-NetConnection 192.168.100.2 -Port 8090
  Test-NetConnection 192.168.100.2 -Port 9443

Depois:

  nslookup ubuntu.com
  nslookup doubleclick.net

E, por fim, teste DHCP:

  ipconfig /release
  ipconfig /renew
  ipconfig /all

Esperado no Wi-Fi:
  DHCP Server : 192.168.100.2
  Gateway     : 192.168.100.1
  DNS         : 192.168.100.2

Observação:
- A porta 3000 do AdGuard NÃO é liberada.
- A porta 68 UDP NÃO é liberada como serviço.
- O Unbound 5335 permanece somente em 127.0.0.1.
- Beszel Agent NÃO expõe a porta 45876.
============================================================
EOT
