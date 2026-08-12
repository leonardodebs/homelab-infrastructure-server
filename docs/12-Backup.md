# 12 — Backup e restauração

A estratégia atual usa uma **mídia USB de 128 GB nominais**, validada com F3, formatada em ext4 e montada em `/srv/backup`.

O passo a passo detalhado está em:

- [16 — Mídia USB dedicada ao backup](16-HD-Externo-Backup.md)

## Arquitetura

```text
SATA Flash interno de 32 GB
└── produção: Ubuntu, Docker e serviços

Mídia USB de 128 GB
└── /srv/backup
    ├── restic
    ├── restore-tests
    └── status
```

A mídia USB não hospeda serviços de produção. Ela é dedicada à recuperação.

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
- Beszel Hub;
- Beszel Agent;
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

A mídia USB é uma cópia local. Ela não implementa 3-2-1 sozinha e não protege contra roubo, incêndio, surto elétrico que atinja ambos os equipamentos ou falha física simultânea.

Evoluções possíveis:

- segunda mídia de backup;
- cópia criptografada externa/off-site;
- uso futuro do HD de maior capacidade como segunda camada de recuperação.
