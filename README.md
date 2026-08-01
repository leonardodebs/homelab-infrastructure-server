# HomeLab Infrastructure Server

Servidor doméstico de baixo consumo baseado em **Dell Wyse N03D**, **Ubuntu Server 24.04 LTS**, Docker e serviços de infraestrutura para a rede residencial.

## Objetivo

Centralizar no Dell Wyse os serviços essenciais da casa:

- DHCP para distribuição automática de IP, gateway e DNS;
- DNS com bloqueio de anúncios e rastreadores pelo AdGuard Home;
- resolução DNS recursiva e cache local com Unbound;
- gerenciamento de containers pelo Portainer;
- monitoramento pelo Uptime Kuma;
- verificação controlada de atualizações com Watchtower;
- firewall, backups e manutenção documentada.

## Hardware do projeto

| Componente | Especificação |
|---|---|
| Equipamento | Dell Wyse N03D / 3290 |
| CPU | Intel Celeron N2807 |
| RAM | 4 GB DDR3 |
| Armazenamento | SSD mSATA 16 GB |
| Rede principal | Ethernet |
| Recursos extras | HDMI e Wi-Fi |
| Sistema | Ubuntu Server 24.04 LTS amd64 |

> O SSD de 16 GB é suficiente para a primeira versão, mas exige controle de logs e backups externos. O upgrade futuro recomendado é mSATA de 120 ou 240 GB.

## Endereçamento adotado

| Item | Valor de referência |
|---|---|
| Rede | `192.168.100.0/24` |
| Modem/gateway | `192.168.100.1` |
| Dell Wyse | `192.168.100.10` |
| Pool DHCP | `192.168.100.50` a `192.168.100.200` |
| Domínio local opcional | `home.arpa` |

Adapte os valores antes da instalação caso a sua rede use outra faixa.

## Arquitetura

```mermaid
flowchart TD
    Internet --> Modem[Huawei HG8145V5-V2\nNAT + Wi-Fi\nDHCP desativado]
    Modem --> Wyse[Dell Wyse\nUbuntu Server\n192.168.100.10]
    Wyse --> AGH[AdGuard Home\nDNS + DHCP]
    AGH --> Unbound[Unbound\n127.0.0.1:5335]
    Unbound --> Root[DNS Root/Autoritativos]
    Wyse --> Portainer
    Wyse --> Kuma[Uptime Kuma]
    Wyse --> Watchtower
    Modem --> Clientes[Notebooks, celulares, TVs e demais clientes]
    Clientes --> AGH
```

## Decisões técnicas importantes

1. O Wyse deve usar **Ethernet** e IP estático. O Wi-Fi fica apenas como contingência.
2. O DHCP do modem só será desligado depois que o AdGuard Home estiver testado.
3. O AdGuard Home usa `network_mode: host`, requisito recomendado para DHCP e identificação real dos clientes.
4. O Unbound roda como serviço nativo do Ubuntu em `127.0.0.1:5335`.
5. O Watchtower não atualiza automaticamente o DNS/DHCP. Serviços críticos são atualizados manualmente após backup.
6. Portas administrativas ficam disponíveis somente na rede local e nenhuma porta deve ser encaminhada no modem para a Internet.

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
11. [Watchtower](docs/10-Watchtower.md)
12. [Firewall UFW](docs/11-UFW.md)
13. [Backup e restauração](docs/12-Backup.md)
14. [Manutenção](docs/13-Manutencao.md)
15. [Troubleshooting](docs/14-Troubleshooting.md)
16. [Upgrades futuros](docs/15-Upgrade.md)

## Estrutura do repositório

```text
.
├── README.md
├── compose/
│   ├── compose.yaml
│   └── .env.example
├── config/
│   └── unbound/
│       └── homelab.conf
├── docs/
└── scripts/
    ├── bootstrap-host.sh
    ├── install-docker.sh
    ├── deploy-stack.sh
    ├── backup.sh
    ├── restore.sh
    ├── update-stack.sh
    └── healthcheck.sh
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

Depois instale o Unbound e suba a stack conforme os capítulos 7 e 6.

## Aviso sobre o corte de DHCP

Nunca desative o DHCP do modem antes de:

- fixar o IP do Wyse;
- validar o AdGuard Home na porta 53;
- configurar e testar o DHCP do AdGuard;
- manter um notebook com IP manual de emergência.

## Estado do projeto

- [x] Arquitetura definida
- [x] Documentação inicial
- [x] Compose dos serviços
- [x] Scripts operacionais
- [ ] Instalação física do Wyse
- [ ] Testes no hardware real
- [ ] Evidências e capturas de tela

## Referências oficiais

- Ubuntu Server: https://documentation.ubuntu.com/server/
- Docker Engine: https://docs.docker.com/engine/install/ubuntu/
- AdGuard Home: https://github.com/AdguardTeam/AdGuardHome/wiki
- Unbound: https://unbound.docs.nlnetlabs.nl/
- Portainer: https://docs.portainer.io/
- Uptime Kuma: https://github.com/louislam/uptime-kuma
- Watchtower: https://containrrr.dev/watchtower/
- OISD: https://oisd.nl/setup/adguardhome
