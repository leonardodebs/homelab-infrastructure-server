# 13 — Backup e restauração

A estratégia atual usa um **pendrive USB de 15 GB**, formatado em ext4 e montado em `/srv/backup`. O repositório Restic tem cerca de 500 MB deduplicados (`restore-size` ~2,3 GiB), então 15 GB são suficientes com folga para a retenção atual (7/8/12/2).

O passo a passo detalhado está em:

- [17 — Pendrive dedicado ao backup](17-Pendrive-Backup.md)

## Arquitetura

```text
SATA Flash interno de 32 GB
└── produção: Ubuntu, Docker e serviços

Pendrive USB de 15 GB
└── /srv/backup
    ├── restic
    ├── restore-tests
    └── status
```

O pendrive não hospeda serviços de produção. Ele é dedicado à recuperação.

## Tecnologia

A stack utiliza:

- ext4;
- montagem por UUID em `/srv/backup`;
- Restic para backup criptografado, incremental e deduplicado;
- systemd timers;
- `flock` para impedir operações Restic simultâneas;
- manutenção com retenção, prune e check parcial;
- teste mensal de restauração em diretório isolado;
- SMART somente quando a mídia/ponte USB oferece suporte.

## Escopo protegido

O backup atual inclui:

- repositório e arquivos Compose do HomeLab;
- `/etc/fstab`;
- Netplan;
- Unbound;
- configuração do Docker;
- UFW e `/etc/default/ufw`;
- units do systemd;
- MOTD customizado do HomeLab;
- configuração da própria rotina Restic, sem a senha;
- volumes persistentes do Portainer;
- AdGuard Home;
- Uptime Kuma;
- Diun.

O HomeLab Web é protegido pelo próprio repositório Git, pois seus arquivos ficam em `web/`.

Não são incluídos:

- `/etc/homelab-backup/restic-password`;
- `/srv/backup` como origem;
- imagens e layers recriáveis do Docker;
- caches e logs temporários.

## Agendamento

| Rotina | Frequência |
|---|---|
| Snapshot | diariamente às 03:15 + `RandomizedDelaySec=5m` |
| Retenção, prune, check parcial e tentativa de SMART | domingo às 04:30 + `RandomizedDelaySec=10m` |
| Teste de restauração | dia 1 de cada mês às 05:30 + `RandomizedDelaySec=15m` |

Todos os timers usam a hora local do host, configurada como `America/Sao_Paulo`.

## Retenção

- 7 diários;
- 8 semanais;
- 12 mensais;
- 2 anuais.

O `restic forget` usa `--group-by host,tags` (não o padrão `host,paths`). Como todos os snapshots usam `--host homelab --tag homelab`, a política acima é aplicada ao conjunto inteiro, independente de quais volumes entraram em cada snapshot. Sem isso, cada mudança no conjunto de origens (ex.: Beszel saiu, Caddy entrou) criaria um "grupo" novo que mantinha os próprios 7 diários, deixando snapshots antigos presos além do previsto.

## Primeiro backup validado

A implantação produziu um snapshot inicial real com sucesso.

Evidências observadas:

```text
status=success
snapshot=a79a4c33
```

O snapshot continha 279 arquivos e 205 diretórios, totalizando 604 itens de filesystem e aproximadamente 5.878 MiB restauráveis no momento do teste inicial.

## Backup automático validado

O `homelab-backup.timer` executou automaticamente em produção e criou um segundo snapshot:

```text
LastTriggerUSec=Wed 2026-08-12 03:15:50 -03
snapshot=85e06611
started_at=2026-08-12T03:15:57-03:00
finished_at=2026-08-12T03:16:08-03:00
status=success
```

O Restic reutilizou o snapshot anterior como parent:

```text
using parent snapshot a79a4c33
Files: 6 new, 18 changed, 261 unmodified
snapshot 85e06611 saved
```

Isso comprova:

- disparo automático pelo systemd timer;
- execução incremental/deduplicada;
- aplicação da política de retenção;
- atualização do marcador `last-success.txt`;
- encerramento bem-sucedido do serviço;
- continuidade dos containers após a janela de consistência.

## Integridade validada

Foi executado:

```bash
sudo bash -c '
set -a
source /etc/homelab-backup/restic.env
set +a
restic check
'
```

Resultado:

```text
no errors were found
```

## Restore test validado

O primeiro teste de restauração recuperou o snapshot em diretório isolado e criou:

```text
/srv/backup/restore-tests/20260811-230507/RESTORE_TEST_OK.txt
```

Conteúdo observado:

```text
status=success
finished_at=2026-08-11T23:05:12-03:00
files_restored=279
snapshot=latest
```

O Restic reportou 604 arquivos/diretórios restaurados, enquanto o script registrou 279 arquivos porque conta somente objetos `-type f`.

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

Restore test:

```bash
sudo systemctl start homelab-restore-test.service
sudo journalctl -u homelab-restore-test.service --no-pager -n 100
```

Listar snapshots:

```bash
sudo bash -c 'source /etc/homelab-backup/restic.env; restic snapshots'
```

## Validação dos timers

```bash
systemctl list-timers --all 'homelab-*' --no-pager
systemctl show homelab-backup.timer -p LastTriggerUSec -p NextElapseUSecRealtime
systemctl cat homelab-backup.timer
systemctl cat homelab-backup-maintenance.timer
systemctl cat homelab-restore-test.timer
```

O horário mostrado em `NEXT` pode ser alguns minutos posterior ao `OnCalendar` por causa do `RandomizedDelaySec`. Isso é esperado e não representa erro de timezone.

## Restauração manual segura

```bash
sudo ./scripts/restore.sh latest
```

O script restaura em diretório separado dentro de `/srv/backup/manual-restore/` e não substitui automaticamente arquivos ativos.

## Proteções implementadas

- backup cancelado se `/srv/backup` não estiver montado;
- `flock` evita operações concorrentes;
- containers stateful são interrompidos brevemente;
- `trap` reinicia somente os containers que estavam ativos;
- senha Restic fica fora do repositório e do próprio backup;
- restore test mensal comprova legibilidade dos snapshots;
- mídia pode ser desconectada com segurança depois de parar timers/serviços e desmontar.

## Limitações

O pendrive é uma cópia local. Ele não implementa 3-2-1 sozinho e não protege contra roubo, incêndio, surto elétrico que atinja ambos os equipamentos ou falha física simultânea.

Evoluções possíveis:

- **cópia no servidor Lenovo (`192.168.15.3`, ~180 GB livres)** — planejada como próxima etapa: `restic copy` para um segundo repositório (rest-server ou SFTP) depois de cada backup local, fechando o 3-2-1 com duas máquinas;
- cópia criptografada externa/off-site (fora da residência);
- segundo pendrive rotacionado.

## Visualização e restore assistido

O [Backrest](21-Backrest.md) fornece uma interface web (`https://backrest.home.arpa`) para navegar snapshots, ver estatísticas e restaurar arquivos pelo navegador. Ele monta o repositório **somente leitura** — o executor dos backups continua sendo o `systemd`.
