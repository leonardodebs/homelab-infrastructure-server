#!/usr/bin/env bash
set -Eeuo pipefail

# HomeLab - Configuração segura do UFW
# Rede LAN: 192.168.100.0/24
# Servidor: 192.168.100.2
# Interface LAN: detectada dinamicamente pelo IP do servidor
# Rede Docker: detectada dinamicamente a partir de homelab_default

LAN_CIDR="192.168.100.0/24"
SERVER_IP="192.168.100.2"
DOCKER_NETWORK="homelab_default"
LAN_IF="$(ip -o -4 addr show | awk -v ip="$SERVER_IP" '$4 ~ "^" ip "/" {print $2; exit}')"

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[AVISO]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[ERRO]\033[0m %s\n' "$*" >&2; exit 1; }

if [[ $EUID -ne 0 ]]; then
  die "Execute com sudo: sudo bash $0"
fi

log "Etapa 1/8 - Pré-validações"
command -v ufw >/dev/null 2>&1 || die "UFW não está instalado."
[[ -n "$LAN_IF" ]] || die "Não foi possível detectar a interface que possui $SERVER_IP."
ip link show "$LAN_IF" >/dev/null 2>&1 || die "Interface detectada $LAN_IF não existe."
ip -4 addr show dev "$LAN_IF" | grep -q "$SERVER_IP/" || die "O IP $SERVER_IP não foi encontrado na interface $LAN_IF."

IPV6_VALUE="$(awk -F= '/^IPV6=/{print $2}' /etc/default/ufw 2>/dev/null || true)"
if [[ "$IPV6_VALUE" != "yes" ]]; then
  die "Esperado IPV6=yes em /etc/default/ufw. Valor atual: ${IPV6_VALUE:-não encontrado}"
fi

command -v docker >/dev/null 2>&1 || die "Docker não está instalado; não foi possível detectar a rede do Uptime Kuma."
DOCKER_CIDR="$(docker network inspect "$DOCKER_NETWORK" --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || true)"
[[ -n "$DOCKER_CIDR" ]] || die "Não foi possível detectar a subnet da rede Docker $DOCKER_NETWORK."

ok "Interface LAN detectada: $LAN_IF"
ok "IP do servidor: $SERVER_IP"
ok "Rede autorizada: $LAN_CIDR"
ok "Rede Docker detectada: $DOCKER_NETWORK -> $DOCKER_CIDR"
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
ufw default deny routed
ok "Entrada padrão: DENY"
ok "Saída padrão: ALLOW"
ok "Forward/routed padrão: DENY"

log "Etapa 4/8 - Liberando SSH PRIMEIRO"
ufw allow from "$LAN_CIDR" to any port 22 proto tcp comment 'SSH LAN'
ok "SSH TCP/22 permitido somente para $LAN_CIDR"

log "Etapa 5/8 - Liberando DNS e DHCP"
ufw allow from "$LAN_CIDR" to any port 53 proto tcp comment 'DNS TCP LAN'
ufw allow from "$LAN_CIDR" to any port 53 proto udp comment 'DNS UDP LAN'
ufw allow in on "$LAN_IF" from 0.0.0.0/0 to any port 67 proto udp comment 'DHCP server LAN IPv4'
ok "DNS TCP/UDP 53 permitido para a LAN"
ok "DHCP IPv4 UDP/67 permitido somente pela interface $LAN_IF"

log "Etapa 6/8 - Liberando interfaces web e monitoramento interno"
ufw allow from "$LAN_CIDR" to any port 80 proto tcp comment 'AdGuard Web LAN'
ufw allow from "$LAN_CIDR" to any port 3001 proto tcp comment 'Uptime Kuma LAN'
ufw allow from "$LAN_CIDR" to any port 8080 proto tcp comment 'HomeLab Web LAN'
ufw allow from "$LAN_CIDR" to any port 8090 proto tcp comment 'Beszel LAN'
ufw allow from "$LAN_CIDR" to any port 9443 proto tcp comment 'Portainer LAN'

ufw allow from "$DOCKER_CIDR" to "$SERVER_IP" port 53 proto tcp comment 'Docker monitor DNS TCP'
ufw allow from "$DOCKER_CIDR" to "$SERVER_IP" port 53 proto udp comment 'Docker monitor DNS UDP'
ufw allow from "$DOCKER_CIDR" to "$SERVER_IP" port 80 proto tcp comment 'Docker monitor AdGuard Web'
ufw allow from "$DOCKER_CIDR" to "$SERVER_IP" port 8080 proto tcp comment 'Docker monitor HomeLab Web'
ufw allow from "$DOCKER_CIDR" to "$SERVER_IP" port 8090 proto tcp comment 'Docker monitor Beszel'
ufw allow from "$DOCKER_CIDR" to "$SERVER_IP" port 9443 proto tcp comment 'Docker monitor Portainer'

ok "AdGuard Web TCP/80"
ok "Uptime Kuma TCP/3001"
ok "HomeLab Web TCP/8080"
ok "Beszel TCP/8090"
ok "Portainer TCP/9443"
ok "Monitoramento interno permitido de $DOCKER_CIDR para serviços selecionados no host"

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
ss -lntup | grep -E '(:22|:53|:67|:80|:3001|:8080|:8090|:9443|:5335)\b' || true

cat <<'EOT'

============================================================
PRÓXIMA VALIDAÇÃO - NÃO FECHE ESTA SESSÃO SSH AINDA
============================================================

Abra um novo terminal no notebook e teste:

  Test-NetConnection 192.168.100.2 -Port 22
  Test-NetConnection 192.168.100.2 -Port 80
  Test-NetConnection 192.168.100.2 -Port 3001
  Test-NetConnection 192.168.100.2 -Port 8080
  Test-NetConnection 192.168.100.2 -Port 8090
  Test-NetConnection 192.168.100.2 -Port 9443

Portal HomeLab:
  http://192.168.100.2:8080

Valide também nova conexão SSH, DNS e DHCP conforme docs/11-UFW.md.

Observações:
- A porta 3000 do AdGuard NÃO é liberada.
- UDP/67 é somente DHCPv4.
- O Unbound 5335 permanece em 127.0.0.1.
- Beszel Agent NÃO expõe a porta 45876.
============================================================
EOT
