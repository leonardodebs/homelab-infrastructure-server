# 12 — Backup e restauração

A estratégia oficial do projeto usa um **HD externo Seagate de 1 TB**, conectado por USB e montado em `/srv/backup`. O disco é exclusivo do HomeLab e não recebe arquivos pessoais dos notebooks.

O passo a passo completo está em:

- [16 — HD externo dedicado ao backup](16-HD-Externo-Backup.md)

## Arquitetura

```text
SSD interno de 16 GB
└── produção: Ubuntu, Docker e serviços

HD externo de 1 TB
└── recuperação: snapshots Restic, testes e status
```

O HD não substitui o SSD para execução dos serviços. AdGuard Home, DHCP, Unbound, Portainer e Uptime Kuma continuam no armazenamento interno para não dependerem do cabo USB durante a inicialização.

## Tecnologia

A stack utiliza:

- **ext4** no HD externo;
- montagem por UUID em `/srv/backup`;
- **Restic** para backup criptografado, incremental e deduplicado;
- **systemd timers** para automação;
- **smartmontools** para saúde do disco, quando a ponte USB suporta SMART;
- teste automático de restauração em diretório isolado.

## Escopo protegido

- repositório e arquivos Compose;
- Netplan, Unbound, Docker e UFW;
- volumes do Portainer;
- volumes do AdGuard Home;
- volume do Uptime Kuma;
- configurações da rotina de backup, sem incluir a senha Restic.

Não são armazenadas imagens Docker, caches, camadas `overlay2`, logs temporários ou o próprio conteúdo de `/srv/backup`.

## Agendamento

| Rotina | Frequência |
|---|---|
| Snapshot | diariamente às 03:15 |
| Retenção, prune, check parcial e SMART | domingo às 04:30 |
| Teste de restauração | dia 1 de cada mês às 05:30 |

## Retenção

- 7 diários;
- 8 semanais;
- 12 mensais;
- 2 anuais.

## Execução manual

Backup:

```bash
sudo systemctl start homelab-backup.service
sudo journalctl -u homelab-backup.service -f
```

Manutenção:

```bash
sudo systemctl start homelab-backup-maintenance.service
sudo journalctl -u homelab-backup-maintenance.service --no-pager -n 200
```

Teste de restauração:

```bash
sudo systemctl start homelab-restore-test.service
sudo journalctl -u homelab-restore-test.service --no-pager -n 100
```

Listar snapshots:

```bash
sudo bash -c 'source /etc/homelab-backup/restic.env; restic snapshots'
```

## Restauração segura

O script restaura em uma pasta separada e não substitui automaticamente o ambiente ativo:

```bash
sudo ./scripts/restore.sh latest
```

O destino padrão é:

```text
/srv/backup/manual-restore/AAAAMMDD-HHMMSS
```

Depois da inspeção, os arquivos necessários podem ser copiados manualmente para o ambiente de produção.

## Proteções implementadas

- o backup falha quando `/srv/backup` não está montado;
- duas operações Restic não podem rodar simultaneamente;
- containers com dados persistentes são pausados brevemente;
- um `trap` reinicia os containers que estavam ativos, mesmo em caso de erro;
- a senha não é incluída no próprio repositório;
- o teste mensal comprova que snapshots podem ser lidos e restaurados.

## Limitação

O HD externo é uma cópia local. Ele não protege contra roubo, incêndio, surto que atinja todos os equipamentos ou falha simultânea. A evolução futura é manter uma segunda cópia criptografada fora do HomeLab.
