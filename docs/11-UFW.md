# 11 — Firewall UFW

## Objetivo

Permitir somente o tráfego necessário da rede local `192.168.100.0/24` e da interface LAN `enxd037454bc6c1`.

## Política base

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

## Regras para a LAN

Aplique primeiro a regra de SSH para não perder o acesso remoto:

```bash
sudo ufw allow from 192.168.100.0/24 to any port 22 proto tcp comment 'SSH LAN'
```

Depois aplique os serviços da LAN:

```bash
sudo ufw allow from 192.168.100.0/24 to any port 53 proto tcp comment 'DNS TCP LAN'
sudo ufw allow from 192.168.100.0/24 to any port 53 proto udp comment 'DNS UDP LAN'
sudo ufw allow in on enxd037454bc6c1 from 0.0.0.0/0 to any port 67 proto udp comment 'DHCP server LAN IPv4'
sudo ufw allow from 192.168.100.0/24 to any port 80 proto tcp comment 'AdGuard Web LAN'
sudo ufw allow from 192.168.100.0/24 to any port 3001 proto tcp comment 'Uptime Kuma LAN'
sudo ufw allow from 192.168.100.0/24 to any port 8080 proto tcp comment 'HomeLab Web LAN'
sudo ufw allow from 192.168.100.0/24 to any port 8090 proto tcp comment 'Beszel LAN'
sudo ufw allow from 192.168.100.0/24 to any port 9443 proto tcp comment 'Portainer LAN'
```

A porta `3000/tcp` não é necessária depois do setup inicial do AdGuard Home.

A porta `68/udp` também não é aberta como serviço de entrada permanente. O servidor DHCPv4 do AdGuard escuta em UDP/67. A regra usa origem IPv4 explícita (`0.0.0.0/0`) e é limitada à interface LAN porque clientes sem lease ainda podem iniciar DHCP usando origem `0.0.0.0`.

Não deve existir regra equivalente `67/udp (v6)`: DHCPv6 usa UDP/546 e UDP/547, e o AdGuard não fornece DHCPv6 neste projeto.

O Unbound permanece somente em `127.0.0.1:5335` e não recebe regra de entrada na LAN.

## IPv6

Antes de ativar o UFW, confirme:

```bash
grep '^IPV6=' /etc/default/ufw
```

O esperado é:

```text
IPV6=yes
```

O servidor possui IPv6 global; portanto o firewall deve tratar IPv4 e IPv6. A política `deny incoming` deve permanecer ativa também para IPv6, sem criar liberações administrativas globais desnecessárias.

## Ativação

Confira as regras adicionadas:

```bash
sudo ufw show added
```

Ative:

```bash
sudo ufw --force enable
sudo ufw status numbered
sudo ufw status verbose
```

Mantenha a sessão SSH atual aberta e teste uma segunda sessão SSH antes de encerrar a primeira.

## Docker e UFW

Portas publicadas pelo Docker podem ser processadas pelas regras do Docker antes das regras normais do UFW.

O projeto reduz o risco por estas medidas:

- Portainer, Uptime Kuma, HomeLab Web e Beszel Hub são vinculados explicitamente ao IP `192.168.100.2`;
- o Huawei não possui port forwarding para o Wyse;
- nenhuma interface administrativa deve ser publicada em `0.0.0.0`;
- o AdGuard usa modo host e recebe regras UFW específicas para a LAN.

Se o servidor ganhar outras interfaces, VLANs, VPNs ou exposição externa, implemente regras explícitas na cadeia `DOCKER-USER` além do UFW.

## Verificação no servidor

```bash
sudo ss -lntup
sudo ufw status verbose
```

Portas esperadas na LAN:

```text
22/tcp     SSH
53/tcp     AdGuard DNS
53/udp     AdGuard DNS
67/udp     AdGuard DHCPv4
80/tcp     AdGuard Web
3001/tcp   Uptime Kuma
8080/tcp   HomeLab Web Portal
8090/tcp   Beszel Hub
9443/tcp   Portainer
```

Portas locais esperadas:

```text
127.0.0.1:5335   Unbound
```

## Verificação de outro dispositivo da LAN

Use um **Windows PowerShell local no notebook**, com prompt semelhante a `PS C:\Users\Leonardo>`.

```powershell
Test-NetConnection 192.168.100.2 -Port 22
Test-NetConnection 192.168.100.2 -Port 80
Test-NetConnection 192.168.100.2 -Port 3001
Test-NetConnection 192.168.100.2 -Port 8080
Test-NetConnection 192.168.100.2 -Port 8090
Test-NetConnection 192.168.100.2 -Port 9443
```

Portal interno:

```text
http://192.168.100.2:8080
```

Depois valide nova conexão SSH:

```powershell
ssh leonardo@192.168.100.2
```

Saia da sessão com `exit` e, de volta ao PowerShell local, valide DNS:

```powershell
nslookup ubuntu.com
nslookup doubleclick.net
```

O resolver esperado no notebook é `192.168.100.2`. A consulta de `doubleclick.net` deve retornar bloqueio (`0.0.0.0` e/ou `::`).

Por fim, valide DHCP:

```powershell
ipconfig /release
ipconfig /renew
ipconfig /all
```

No adaptador Wi-Fi, o esperado é:

```text
DHCP Server : 192.168.100.2
Gateway     : 192.168.100.1
DNS         : 192.168.100.2
```

## Regras que não devem existir

- liberações administrativas globais como `ufw allow 9443/tcp` sem origem limitada;
- `ufw allow 3000/tcp` depois do setup do AdGuard;
- regra LAN para o Unbound `5335`;
- regra IPv6 em UDP/67 para DHCP;
- port forwarding no modem;
- exposição de SSH, Portainer, Uptime Kuma, HomeLab Web, Beszel ou AdGuard para a Internet;
- `ufw disable` como solução permanente.
