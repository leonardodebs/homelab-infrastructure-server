# 11 — Firewall UFW

## Objetivo

Permitir somente o tráfego necessário da LAN `192.168.100.0/24` e da rede Docker interna usada pelo Uptime Kuma para alcançar serviços publicados no próprio host.

O nome exato da interface Ethernet é detectado no servidor e não é documentado como identificador público fixo.

## Detectar a interface LAN

```bash
LAN_IF="$(ip -o -4 addr show | awk '$4 ~ /^192\.168\.100\.2\// {print $2; exit}')"
echo "$LAN_IF"
```

O resultado deve corresponder à interface do adaptador TP-Link UE300 que possui `192.168.100.2/24`.

## Política base

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw default deny routed
```

## Regras da LAN

SSH primeiro:

```bash
sudo ufw allow from 192.168.100.0/24 to any port 22 proto tcp comment 'SSH LAN'
```

Serviços:

```bash
sudo ufw allow from 192.168.100.0/24 to any port 53 proto tcp comment 'DNS TCP LAN'
sudo ufw allow from 192.168.100.0/24 to any port 53 proto udp comment 'DNS UDP LAN'
sudo ufw allow in on "$LAN_IF" from 0.0.0.0/0 to any port 67 proto udp comment 'DHCP server LAN IPv4'
sudo ufw allow from 192.168.100.0/24 to any port 80 proto tcp comment 'AdGuard Web LAN'
sudo ufw allow from 192.168.100.0/24 to any port 3001 proto tcp comment 'Uptime Kuma LAN'
sudo ufw allow from 192.168.100.0/24 to any port 8080 proto tcp comment 'HomeLab Web LAN'
sudo ufw allow from 192.168.100.0/24 to any port 8090 proto tcp comment 'Beszel LAN'
sudo ufw allow from 192.168.100.0/24 to any port 9443 proto tcp comment 'Portainer LAN'
```

A porta 3000/tcp do assistente inicial do AdGuard não é necessária depois da instalação.

UDP/67 é DHCPv4. Não deve existir regra equivalente IPv6 para essa porta; DHCPv6 usa portas diferentes e está desativado neste projeto.

O Unbound permanece em `127.0.0.1:5335` e não recebe regra LAN.

## Rede Docker e Uptime Kuma

Descubra a subnet atual:

```bash
DOCKER_CIDR="$(docker network inspect homelab_default \
  --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}')"
echo "$DOCKER_CIDR"
```

No ambiente validado, a rede foi criada como `homelab_default`, mas a subnet não deve ser tratada como valor permanente porque pode mudar se a rede for recriada.

Quando o Uptime Kuma monitora serviços em `192.168.100.2`, o tráfego chega com origem na rede Docker. Por isso são necessárias regras específicas:

```bash
sudo ufw allow from "$DOCKER_CIDR" to 192.168.100.2 port 53 proto tcp comment 'Docker monitor DNS TCP'
sudo ufw allow from "$DOCKER_CIDR" to 192.168.100.2 port 53 proto udp comment 'Docker monitor DNS UDP'
sudo ufw allow from "$DOCKER_CIDR" to 192.168.100.2 port 80 proto tcp comment 'Docker monitor AdGuard Web'
sudo ufw allow from "$DOCKER_CIDR" to 192.168.100.2 port 8080 proto tcp comment 'Docker monitor HomeLab Web'
sudo ufw allow from "$DOCKER_CIDR" to 192.168.100.2 port 8090 proto tcp comment 'Docker monitor Beszel'
sudo ufw allow from "$DOCKER_CIDR" to 192.168.100.2 port 9443 proto tcp comment 'Docker monitor Portainer'
```

O script `scripts/configure-ufw.sh` detecta tanto a interface LAN quanto a subnet Docker antes de aplicar as regras.

## IPv6

```bash
grep '^IPV6=' /etc/default/ufw
```

Esperado:

```text
IPV6=yes
```

O host possui IPv6 global. A política de entrada deve continuar negando tráfego IPv6 não solicitado, sem abrir interfaces administrativas globalmente.

## Ativação e validação

```bash
sudo ufw show added
sudo ufw --force enable
sudo ufw status numbered
sudo ufw status verbose
```

Mantenha uma sessão SSH aberta e valide uma segunda conexão antes de encerrar a primeira.

Sockets esperados:

```text
22/tcp       SSH
53/tcp/udp   AdGuard DNS
67/udp       AdGuard DHCPv4
80/tcp       AdGuard Web
3001/tcp     Uptime Kuma
8080/tcp     HomeLab Web
8090/tcp     Beszel Hub
9443/tcp     Portainer
127.0.0.1:5335 Unbound
```

Valide:

```bash
sudo ss -lntup | grep -E '(:22|:53|:67|:80|:3001|:8080|:8090|:9443|:5335)\b'
```

## Validação a partir de um notebook Windows

```powershell
Test-NetConnection 192.168.100.2 -Port 22
Test-NetConnection 192.168.100.2 -Port 80
Test-NetConnection 192.168.100.2 -Port 3001
Test-NetConnection 192.168.100.2 -Port 8080
Test-NetConnection 192.168.100.2 -Port 8090
Test-NetConnection 192.168.100.2 -Port 9443
nslookup ubuntu.com
nslookup doubleclick.net
```

Depois valide DHCP:

```powershell
ipconfig /all
```

Esperado:

```text
DHCP Server : 192.168.100.2
Gateway     : 192.168.100.1
DNS         : 192.168.100.2
```

## Docker e UFW

Portas publicadas pelo Docker podem ser processadas pelas regras do Docker antes das regras UFW comuns. O projeto reduz o risco usando:

- binding explícito das interfaces web em `192.168.100.2`;
- ausência de port forwarding no Huawei;
- UFW com entrada padrão negada;
- acesso Docker -> host restrito aos checks necessários.

Se o servidor ganhar VPN, VLAN, segunda interface ou exposição externa, revise também a cadeia `DOCKER-USER`.

## Regras que não devem existir

- liberações administrativas globais sem origem limitada;
- porta 3000 do AdGuard após o setup;
- regra LAN para Unbound/5335;
- UDP/67 em IPv6;
- port forwarding no modem para interfaces administrativas;
- exposição da porta 45876 do Beszel Agent;
- `ufw disable` como solução permanente.

## Estado atual

- [x] UFW ativo;
- [x] entrada padrão negada;
- [x] IPv6 tratado pelo firewall;
- [x] serviços administrativos limitados à LAN;
- [x] DHCPv4 limitado à interface LAN;
- [x] regras Docker -> host validadas com Uptime Kuma;
- [x] nenhuma porta administrativa encaminhada no modem.
