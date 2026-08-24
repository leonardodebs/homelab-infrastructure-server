# 00 — Arquitetura

## Objetivo

Transformar o Dell Wyse em servidor de infraestrutura doméstica de baixo consumo, mantendo o Huawei HG8145V5-V2 como gateway, NAT e ponto de acesso Wi-Fi.

## Estado atual validado

### Huawei HG8145V5-V2

- acesso à Internet;
- NAT;
- Wi-Fi;
- gateway `192.168.100.1`;
- DHCPv4 desativado após a migração para o AdGuard Home.

### Dell Wyse N03D / 3290

- Ubuntu Server 24.04.4 LTS;
- hostname `homelab`;
- IP estático `192.168.100.2`;
- Ethernet principal via adaptador USB TP-Link UE300;
- Docker Engine e Compose;
- Portainer;
- AdGuard Home como DNS e DHCPv4;
- Unbound como resolvedor DNS recursivo local;
- Uptime Kuma para disponibilidade;
- Node Exporter e cAdvisor exportando métricas para Prometheus/Grafana no Lenovo;
- ntopng para análise de tráfego e hosts visíveis pela interface do HomeLab;
- Diun para detecção de novas imagens;
- HomeLab Web como portal interno;
- UFW como firewall do host;
- Restic em mídia USB dedicada para backup e restore test.

## Topologia

```mermaid
flowchart TD
    Internet --> Huawei[Huawei HG8145V5-V2\n192.168.100.1\nNAT + Wi-Fi\nDHCP desativado]
    Huawei --> Wyse[Dell Wyse\nhomelab\n192.168.100.2\nUbuntu Server]
    Huawei --> Clientes[Notebooks, celulares, TVs e demais clientes]
    Clientes -->|DHCP + DNS| AdGuard[AdGuard Home\nDNS :53 + DHCPv4 :67]
    AdGuard -->|127.0.0.1:5335| Unbound[Unbound\nDNS recursivo + cache]
    Unbound --> Internet
    Wyse --> Portainer[Portainer :9443]
    Wyse --> Kuma[Uptime Kuma :3001]
    Wyse --> Exporters[Node Exporter :9100\ncAdvisor :8081]
    Exporters --> Grafana[Prometheus + Grafana\n192.168.100.3]
    Wyse --> Ntop[ntopng :3000\nAnálise de tráfego]
    Wyse --> Diun[Diun\nImage Update Notifier]
    Wyse --> Portal[HomeLab Web :8080]
    Wyse --> Backup[Restic\n/srv/backup]
```

## Fluxo DHCP

1. O cliente entra na rede.
2. O AdGuard Home entrega:
   - IP no pool `192.168.100.50-192.168.100.200`;
   - máscara `/24`;
   - gateway `192.168.100.1`;
   - DNS `192.168.100.2`;
   - domínio local `home.arpa`.
3. O servidor permanece fora do pool DHCP.
4. Reservas podem ser usadas para clientes que precisem de IP previsível.

## Fluxo DNS

```text
Cliente -> AdGuard Home -> Unbound -> servidores raiz/autoritativos
```

O AdGuard aplica listas de bloqueio, regras locais e políticas por cliente. Consultas permitidas seguem para o Unbound, que resolve recursivamente, valida DNSSEC e mantém cache local.

## Observabilidade

- Uptime Kuma verifica gateway, Internet, DNS e interfaces web;
- Prometheus e Grafana registram CPU, RAM, swap, disco, rede, temperatura e containers;
- ntopng acrescenta análise de tráfego, hosts, protocolos e fluxos observáveis pela interface Ethernet do HomeLab;
- AdGuard Home fornece histórico de consultas DNS e identificação de clientes;
- o portal HomeLab centraliza os links administrativos;
- logs do Docker e do systemd permanecem disponíveis para troubleshooting.

### Limitação do ntopng

O Huawei continua sendo o gateway da residência. Como o Dell Wyse não está inline entre os clientes e a Internet, o ntopng não observa automaticamente todo o tráfego da LAN.

A visibilidade integral exigiria uma evolução de arquitetura, por exemplo:

- gateway/firewall dedicado;
- switch gerenciável com SPAN/port mirroring;
- exportação de fluxos pela infraestrutura de rede, quando suportada.

No desenho atual, o ntopng é uma ferramenta complementar de observabilidade do HomeLab.

## Atualizações de containers

O Diun consulta os registries e detecta mudanças nas imagens marcadas com `diun.enable=true`.

Ele não atualiza containers automaticamente. A atualização é executada manualmente em janela de manutenção, após backup e revisão.

## Backup e recuperação

A mídia atual é um pendrive USB de 128 GB nominais, validado com F3, formatado em ext4 e montado em `/srv/backup`.

O Restic fornece:

- snapshots criptografados e incrementais;
- retenção automática;
- verificação periódica de integridade;
- teste mensal de restauração em diretório isolado.

O primeiro backup e o primeiro restore test foram executados com sucesso.

## Endereçamento de referência

| Recurso | Endereço |
|---|---|
| Rede | `192.168.100.0/24` |
| Gateway/modem | `192.168.100.1` |
| Dell Wyse | `192.168.100.2` |
| DHCP | AdGuard Home |
| Pool DHCP | `192.168.100.50-192.168.100.200` |
| Unbound | `127.0.0.1:5335` |
| AdGuard Web | `http://192.168.100.2` |
| ntopng | `http://192.168.100.2:3000` |
| Uptime Kuma | `http://192.168.100.2:3001` |
| HomeLab Web | `http://192.168.100.2:8080` |
| Grafana | `http://192.168.100.3:3000` |
| Portainer | `https://192.168.100.2:9443` |

## Restrições e boas práticas

- O Wyse opera pela Ethernet principal; Wi-Fi não participa da operação crítica.
- Nenhuma interface administrativa é encaminhada no modem para a Internet.
- O Unbound permanece somente em loopback.
- Os exporters `9100/tcp` e `8081/tcp` aceitam somente o Prometheus em `192.168.100.3`.
- O ntopng permanece acessível apenas pela LAN e sua visibilidade é limitada ao tráfego observável pela interface monitorada.
- Atualizações de DNS/DHCP não são automatizadas.
- Backup deve preceder alterações relevantes na stack.
- O armazenamento interno de 32 GB deve permanecer enxuto.

## Ordem de implantação concluída

1. Ubuntu Server instalado.
2. Hostname e IP estático definidos.
3. Docker e Portainer instalados.
4. Unbound instalado e validado.
5. AdGuard Home instalado e validado.
6. DHCP migrado do Huawei para o AdGuard.
7. Uptime Kuma instalado e monitores configurados.
8. Beszel aposentado após migração para Prometheus e Grafana.
9. Diun instalado.
10. HomeLab Web publicado na LAN.
11. UFW aplicado e validado.
12. Mídia USB preparada.
13. Restic instalado, backup criado, `restic check` executado e restauração testada.
14. ntopng instalado nativamente, porta `3000/tcp` liberada na LAN e dashboard validado.
