# 11 — Firewall UFW

## Objetivo

Permitir somente o tráfego necessário da rede local `192.168.100.0/24`.

## Política base

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

## Regras para a LAN

```bash
sudo ufw allow from 192.168.100.0/24 to any port 22 proto tcp comment 'SSH LAN'
sudo ufw allow from 192.168.100.0/24 to any port 53 proto tcp comment 'DNS TCP LAN'
sudo ufw allow from 192.168.100.0/24 to any port 53 proto udp comment 'DNS UDP LAN'
sudo ufw allow from 192.168.100.0/24 to any port 67 proto udp comment 'DHCP LAN'
sudo ufw allow from 192.168.100.0/24 to any port 68 proto udp comment 'DHCP client LAN'
sudo ufw allow from 192.168.100.0/24 to any port 80 proto tcp comment 'AdGuard Web LAN'
sudo ufw allow from 192.168.100.0/24 to any port 3000 proto tcp comment 'AdGuard setup LAN'
sudo ufw allow from 192.168.100.0/24 to any port 3001 proto tcp comment 'Uptime Kuma LAN'
sudo ufw allow from 192.168.100.0/24 to any port 9443 proto tcp comment 'Portainer LAN'
```

Ative e confira:

```bash
sudo ufw --force enable
sudo ufw status numbered
```

## Docker e UFW

Portas publicadas pelo Docker podem ser tratadas antes das regras normais do UFW. Este projeto reduz o risco de três formas:

- Portainer e Uptime Kuma são vinculados explicitamente ao IP `192.168.100.2`;
- o modem não possui encaminhamento de portas para o Wyse;
- o AdGuard usa modo host, mas as regras UFW limitam o acesso à LAN.

Para um ambiente com múltiplas interfaces ou exposição externa, implemente regras adicionais na cadeia `DOCKER-USER`.

## Verificação

```bash
sudo ss -lntup
sudo ufw status verbose
```

De outro dispositivo na LAN:

```powershell
Test-NetConnection 192.168.100.2 -Port 22
Test-NetConnection 192.168.100.2 -Port 9443
Test-NetConnection 192.168.100.2 -Port 3001
```

## Regras que não devem existir

- `ufw allow 9443/tcp` sem origem limitada;
- port forwarding no modem;
- exposição de SSH, Portainer ou AdGuard para a Internet;
- `ufw disable` como solução permanente.
