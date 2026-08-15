# 18 — Horário e agendamentos

Este documento registra a política de tempo do HomeLab e a auditoria realizada sobre timezone, RTC, NTP, systemd timers, cron e schedulers em containers.

## Política temporal do host

Estado validado:

```text
Timezone             America/Sao_Paulo
Offset local          -03:00
/etc/localtime        America/Sao_Paulo
/etc/timezone         America/Sao_Paulo
RTC                   UTC
RTC em hora local     não
NTP                   systemd-timesyncd
Sincronização NTP     ativa
```

O RTC permanece em UTC e o sistema operacional apresenta a hora local conforme `America/Sao_Paulo`.

## Validação do host

```bash
date
date -Is
timedatectl
readlink -f /etc/localtime
cat /etc/timezone
timedatectl timesync-status
systemctl status systemd-timesyncd --no-pager
```

Critérios esperados:

```text
Time zone: America/Sao_Paulo (-03, -0300)
System clock synchronized: yes
NTP service: active
RTC in local TZ: no
```

## NTP

O host usa `systemd-timesyncd` e foi observado sincronizado com a infraestrutura NTP padrão do Ubuntu.

Não fixe manualmente a hora enquanto o NTP estiver funcionando. Em caso de divergência, investigue primeiro rede, DNS e estado do `systemd-timesyncd`.

## Timers do HomeLab

### Backup diário

```text
OnCalendar=*-*-* 03:15:00
RandomizedDelaySec=5m
AccuracySec=1m
Persistent=true
```

Janela operacional esperada:

```text
03:15–03:20
```

Execução automática real já validada.

### Manutenção do Restic

```text
OnCalendar=Sun *-*-* 04:30:00
RandomizedDelaySec=10m
AccuracySec=1m
Persistent=true
```

Janela operacional esperada:

```text
domingo 04:30–04:40
```

### Restore test

```text
OnCalendar=*-*-01 05:30:00
RandomizedDelaySec=15m
AccuracySec=1m
Persistent=true
```

Janela operacional esperada:

```text
dia 1 de cada mês, 05:30–05:45
```

## Por que o horário `NEXT` pode variar

Os timers do HomeLab utilizam `RandomizedDelaySec`. Por isso, um timer com base em `03:15` pode aparecer em `systemctl list-timers` como `03:18`, por exemplo.

Isso é esperado e não indica problema de timezone.

Auditoria:

```bash
systemctl list-timers --all 'homelab-*' --no-pager
systemctl cat homelab-backup.timer
systemctl cat homelab-backup-maintenance.timer
systemctl cat homelab-restore-test.timer
```

## APT e unattended-upgrades

Os timers padrão do Ubuntu também usam mecanismos de randomização. Portanto, `apt-daily.timer` e `apt-daily-upgrade.timer` não devem ser tratados como jobs de horário fixo.

Validação:

```bash
systemctl status apt-daily.timer --no-pager
systemctl status apt-daily-upgrade.timer --no-pager
systemctl list-timers --all --no-pager | grep -E 'apt-daily|apt-daily-upgrade'
```

A política do HomeLab permite atualizações automáticas elegíveis sem reboot automático não supervisionado.

## Cron

O daemon `cron` permanece ativo para tarefas padrão do Ubuntu/pacotes.

Na auditoria:

- não havia crontab do usuário;
- não havia crontab adicional do root;
- `/etc/crontab` continha apenas jobs padrão;
- não havia `CRON_TZ` customizado.

Comandos:

```bash
crontab -l
sudo crontab -l
sudo cat /etc/crontab
sudo grep -RniE 'CRON_TZ|^[^#].*[0-9].*' /etc/cron.d/ 2>/dev/null
```

O cron usa a hora local do host.

## Sysstat

O `sysstat-collect.timer` está ativo e executa:

```text
OnCalendar=*:00/10
```

A coleta real ocorre a cada 10 minutos por:

```text
sysstat-collect.timer
  -> sysstat-collect.service
  -> /usr/lib/sysstat/sa1 1 1
  -> /var/log/sysstat/saDD
```

Embora `/etc/cron.d/sysstat` exista, a auditoria dos arquivos `saDD` e do comando `sar` mostrou amostras efetivas apenas no ciclo do systemd timer, sem duplicidade a cada 5 minutos.

Validação:

```bash
systemctl status sysstat-collect.timer --no-pager
journalctl -u sysstat-collect.service --since today --no-pager
sudo sar -f /var/log/sysstat/sa$(date +%d)
```

## Containers e timezone

Nem todo container precisa usar a hora local do host.

Na auditoria foram encontrados containers executando internamente em UTC. Isso é aceitável para serviços sem agendamento baseado em hora local, desde que logs e interfaces sejam interpretados corretamente.

O Diun é exceção porque possui scheduler próprio e está explicitamente configurado com:

```text
TZ=America/Sao_Paulo
DIUN_WATCH_SCHEDULE=0 4 * * 0
DIUN_WATCH_JITTER=30s
```

Portanto, a verificação agendada ocorre aos domingos às 04:00 no horário local.

## Auditoria de timezone dos containers

```bash
for c in $(docker ps --format '{{.Names}}'); do
  echo
  echo "--- $c ---"
  docker exec "$c" date '+%Y-%m-%d %H:%M:%S %z %Z' 2>/dev/null \
    || echo 'container sem comando date'
done
```

Algumas imagens minimalistas não possuem o comando `date`; isso não representa falha do container.

Para variáveis de ambiente relacionadas a timezone/schedule:

```bash
for c in $(docker ps --format '{{.Names}}'); do
  echo
  echo "--- $c ---"
  docker inspect "$c" \
    --format '{{range .Config.Env}}{{println .}}{{end}}' \
    | grep -Ei '^(TZ|TIMEZONE|DIUN_.*SCHEDULE)=' \
    || echo 'sem TZ/schedule explícito'
done
```

## Matriz operacional de horários

| Rotina | Base | Janela/observação |
|---|---:|---|
| Backup Restic | 03:15 diário | até 5 min de jitter |
| Diun | 04:00 domingo | jitter interno pequeno |
| Manutenção Restic | 04:30 domingo | até 10 min de jitter |
| Restore test | 05:30 dia 1 | até 15 min de jitter |
| APT | automático | horário variável por randomização |
| Sysstat | a cada 10 min | systemd timer |

Não há colisão operacional relevante entre as rotinas principais do HomeLab.

## Checklist de auditoria

```bash
printf '\n===== RESUMO =====\n'
printf 'HOST:        '; hostname
printf 'DATE:        '; date '+%Y-%m-%d %H:%M:%S %z %Z'
printf 'TIMEZONE:    '; timedatectl show -p Timezone --value
printf 'NTP SYNC:    '; timedatectl show -p NTPSynchronized --value
printf 'RTC LOCAL:   '; timedatectl show -p LocalRTC --value
printf 'UPTIME:      '; uptime -p

systemctl list-timers --all 'homelab-*' --no-pager
```

Estado esperado:

```text
TIMEZONE    America/Sao_Paulo
NTP SYNC    yes
RTC LOCAL   no
```

## Princípios operacionais

1. RTC permanece em UTC.
2. O host usa `America/Sao_Paulo`.
3. `/etc/localtime` e `/etc/timezone` devem permanecer coerentes.
4. NTP permanece ativo.
5. Jitter de timers não deve ser confundido com erro de timezone.
6. Containers podem usar UTC quando não dependem de hora local.
7. Schedulers que dependem de horário local devem declarar timezone explicitamente quando necessário.
8. Não altere manualmente horários de jobs padrão do Ubuntu sem necessidade operacional comprovada.
