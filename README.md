# HomeLab Infrastructure Server

Servidor doméstico de baixo consumo baseado em **Dell Wyse N03D / 3290**, **Ubuntu Server 24.04 LTS**, Docker e serviços de infraestrutura para a rede residencial.

## Objetivo

Centralizar no Dell Wyse os serviços essenciais da casa:

- DHCP para distribuição automática de IP, gateway e DNS;
- DNS com bloqueio de anúncios e rastreadores pelo AdGuard Home;
- resolução DNS recursiva e cache local com Unbound;
- gerenciamento de containers pelo Portainer;
- monitoramento pelo Uptime Kuma;
- verificação controlada de atualizações de imagens com Diun;
- firewall, backups e manutenção documentada;
- recuperação local por HD externo com Restic.

## Hardware do projeto

| Componente | Especificação |
|---|---|
| Equipamento | Dell Wyse N03D / 3290 |
| CPU | Intel Celeron N2807 @ 1.58 GHz |
| RAM | 4 GB DDR3 / 1333 MT/s |
| Armazenamento de produção atual | SATA Flash Drive 32 GB |
| Upgrade planejado | SSD 120 GB no fim de 2026 |
| Armazenamento de backup | HD externo Seagate 1 TB via USB |
| Rede principal | TP-Link UE300 USB 3.0 Gigabit Ethernet |
| Recursos extras | HDMI, VGA, USB e Wi-Fi |
| Sistema atual | Ubuntu Server 24.04.4 LTS amd64 |
| BIOS observada | Phoenix SecureCore, versão 1.0R (2017-12-22) |

## Endereçamento adotado

| Item | Valor de referência |
|---|---|
| Rede | `192.168.100.0/24` |
| Modem/gateway | `192.168.100.1` |
| Dell Wyse | `192.168.100.2` |
| Pool DHCP | `192.168.100.50` a `192.168.100.200` |
| Domínio local | `home.arpa` |

## Arquitetura

```mermaid
flowchart TD
    Internet --> Modem[Huawei HG8145V5-V2\nNAT + Wi-Fi\nDHCP desativado]
    Modem --> Wyse[Dell Wyse\nUbuntu Server\n192.168.100.2]
    Wyse --> AGH[AdGuard Home\nDNS + DHCP]
    AGH --> Unbound[Unbound\n127.0.0.1:5335]
    Unbound --> RootDNS[DNS Root/Autoritativos]
    Wyse --> Portainer
    Wyse --> Kuma[Uptime Kuma]
    Wyse --> Diun[Diun\nImage Update Notifier]
    Wyse --> SSD[SATA Flash 32 GB\nProdução]
    Wyse --> USB[HD Seagate 1 TB\n/srv/backup]
    USB --> Restic[Restic\nSnapshots criptografados]
    Restic --> Restore[Testes de restauração]
    Modem --> Clientes[Notebooks, celulares, TVs e demais clientes]
    Clientes --> AGH
```

## Decisões técnicas importantes

1. O Wyse usa **Ethernet** e IP estático; o Wi-Fi permanece fora da operação principal.
2. O DHCP do Huawei está desativado e o AdGuard Home entrega DHCPv4 aos clientes.
3. O AdGuard Home usa `network_mode: host`, necessário para DHCP e identificação real dos clientes.
4. O Unbound roda como serviço nativo do Ubuntu em `127.0.0.1:5335`.
5. O Diun apenas detecta novas imagens; atualizações de containers são executadas manualmente após revisão e backup.
6. Portas administrativas ficam disponíveis somente na rede local e nenhuma porta deve ser encaminhada no modem para a Internet.
7. O SATA Flash de 32 GB é o ambiente de produção inicial; o HD externo de 1 TB será o ambiente de recuperação.
8. O backup é cancelado se `/srv/backup` não estiver montado, evitando gravar acidentalmente no armazenamento interno.
9. A senha Restic não é armazenada no repositório e precisa ser guardada fora do servidor.
10. O upgrade para SSD de 120 GB está planejado para o fim de 2026 e será tratado como exercício de disaster recovery/restauração.

## Ordem de implantação

1. [Arquitetura](docs/00-Arquitetura.md)
2. [Hardware e checklist de chegada](docs/01-Hardware.md)
3. [Instalação do Ubuntu Server](docs/02-Instalacao-Ubuntu.md)
4. [Configuração inicial e IP estático](docs/03-Configuracao-Inicial.md)
5. [Docker Engine e Compose](docs/04-Docker.md)
6. [Portainer](docs/05-Portainer.md)
7. [AdGuard Home](docs/06-AdGuardHome.md)
8. [Unbound](docs/07-Unbound.md)
9. [Migração do DHCP](docs/08-DHCP.md)
10. [Uptime Kuma](docs/09-Uptime-Kuma.md)
11. [Diun](docs/10-Diun.md)
12. [Firewall UFW](docs/11-UFW.md)
13. [Backup e restauração](docs/12-Backup.md)
14. [Manutenção](docs/13-Manutencao.md)
15. [Troubleshooting](docs/14-Troubleshooting.md)
16. [Upgrades futuros](docs/15-Upgrade.md)
17. [HD externo e stack Restic](docs/16-HD-Externo-Backup.md)

## Stack de backup externo

| Rotina | Agendamento | Resultado |
|---|---:|---|
| Backup Restic | diariamente às 03:15 | snapshot criptografado e incremental |
| Manutenção | domingo às 04:30 | retenção, prune, check parcial e SMART |
| Restore test | dia 1 às 05:30 | restauração em diretório isolado |

Retenção padrão:

- 7 snapshots diários;
- 8 semanais;
- 12 mensais;
- 2 anuais.

## Estrutura do repositório

```text
.
├── README.md
├── compose/
│   ├── compose.yaml
│   └── .env.example
├── config/
│   ├── restic/
│   │   ├── excludes.txt
│   │   └── restic.env.example
│   └── unbound/
│       └── homelab.conf
├── docs/
├── scripts/
│   ├── bootstrap-host.sh
│   ├── install-docker.sh
│   ├── deploy-stack.sh
│   ├── prepare-backup-disk.sh
│   ├── install-backup-stack.sh
│   ├── restic-backup.sh
│   ├── restic-maintenance.sh
│   ├── restic-restore-test.sh
│   ├── smart-check.sh
│   ├── backup.sh
│   ├── restore.sh
│   ├── update-stack.sh
│   └── healthcheck.sh
└── systemd/
    ├── homelab-backup.service
    ├── homelab-backup.timer
    ├── homelab-backup-maintenance.service
    ├── homelab-backup-maintenance.timer
    ├── homelab-restore-test.service
    └── homelab-restore-test.timer
```

## Uso rápido

Depois de concluir a configuração do Ubuntu e do IP estático:

```bash
git clone https://github.com/leonardodebs/homelab-infrastructure-server.git
cd homelab-infrastructure-server
chmod +x scripts/*.sh
sudo ./scripts/bootstrap-host.sh
./scripts/install-docker.sh
```

Copie o arquivo de ambiente e ajuste o IP:

```bash
cp compose/.env.example compose/.env
nano compose/.env
```

Depois instale o Unbound e suba a stack conforme os capítulos correspondentes.

## Instalação do HD externo

Depois que os serviços estiverem estáveis:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT,MODEL,SERIAL,TRAN
sudo ./scripts/prepare-backup-disk.sh /dev/sdX
sudo ./scripts/install-backup-stack.sh
sudo systemctl start homelab-backup.service
```

O comando de preparação é destrutivo e exige que o disco correto seja identificado pelo modelo, capacidade e serial. Consulte o [capítulo 16](docs/16-HD-Externo-Backup.md) antes de executar.

## Estado do projeto

- [x] Arquitetura definida
- [x] Documentação inicial
- [x] Hardware recebido e validado
- [x] Ubuntu Server 24.04.4 LTS instalado
- [x] IP estático `192.168.100.2`
- [x] Docker Engine e Compose instalados
- [x] Portainer instalado e validado
- [x] Unbound instalado e validado
- [x] AdGuard Home instalado e validado
- [x] DHCP migrado do Huawei para o AdGuard Home
- [x] DNS dos clientes apontando para `192.168.100.2`
- [x] Bloqueio de anúncios validado
- [x] Uptime Kuma instalado e monitores iniciais configurados
- [ ] Diun instalado e validado
- [ ] Firewall UFW aplicado
- [ ] Formatação e validação do HD externo real
- [ ] Stack Restic instalada e restore test validado
- [ ] Evidências e capturas de tela da implantação
- [ ] Upgrade futuro para SSD de 120 GB

## Referências oficiais

- Ubuntu Server: https://documentation.ubuntu.com/server/
- Docker Engine: https://docs.docker.com/engine/install/ubuntu/
- AdGuard Home: https://github.com/AdguardTeam/AdGuardHome/wiki
- Unbound: https://unbound.docs.nlnetlabs.nl/
- Portainer: https://docs.portainer.io/
- Uptime Kuma: https://github.com/louislam/uptime-kuma
- Diun: https://crazymax.dev/diun/
- OISD: https://oisd.nl/setup/adguardhome
- Restic: https://restic.readthedocs.io/en/stable/
- systemd.timer: https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html
- smartmontools: https://www.smartmontools.org/
