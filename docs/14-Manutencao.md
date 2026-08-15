# 14 — Manutenção

## Rotina semanal

Execute a partir do repositório:

```bash
cd ~/homelab-infrastructure-server
./scripts/healthcheck.sh
docker ps --format 'table {{.Names}}\t{{.Status}}'
docker system df
df -h /
df -h /srv/backup
```

Verifique:

- containers reiniciando ou unhealthy;
- falhas no Uptime Kuma;
- CPU, RAM, disco e temperatura no Beszel;
- consultas DNS anormais no AdGuard;
- espaço livre do sistema e do backup;
- último snapshot Restic bem-sucedido;
- mensagens de erro no kernel/USB.

## Horário, NTP e agendamentos

A política temporal do HomeLab é:

```text
Timezone : America/Sao_Paulo
Offset   : -03:00
RTC      : UTC
LocalRTC : no
NTP      : systemd-timesyncd sincronizado
```

Validação rápida:

```bash
date -Is
timedatectl
readlink -f /etc/localtime
cat /etc/timezone
timedatectl timesync-status
```

Audite os agendamentos:

```bash
systemctl list-timers --all --no-pager
systemctl list-timers --all 'homelab-*' --no-pager
```

O backup diário usa base 03:15 com jitter de até 5 minutos; manutenção usa domingo 04:30 com jitter de até 10 minutos; restore test usa dia 1 às 05:30 com jitter de até 15 minutos. O Diun executa aos domingos às 04:00 com `TZ=America/Sao_Paulo`.

Containers sem scheduler local podem permanecer em UTC. Não force `TZ` apenas por uniformidade visual.

O `sysstat` possui `sysstat-collect.timer` ativo e grava amostras a cada 10 minutos. Embora `/etc/cron.d/sysstat` exista, a auditoria mostrou que não há duplicidade efetiva de amostras.

Consulte [18 — Horário e agendamentos](18-Horario-Agendamentos.md) para a auditoria completa.

## Backup

O backup já é agendado por systemd e a execução automática foi validada em produção. Para validar o último sucesso:

```bash
sudo cat /srv/backup/status/last-success.txt
systemctl list-timers 'homelab-*' --no-pager
```

Backup manual antes de uma manutenção relevante:

```bash
./scripts/backup.sh
```

## Atualizações do Ubuntu

```bash
sudo apt update
apt list --upgradable
sudo apt upgrade -y
sudo apt autoremove --purge -y
```

Se houver atualização de kernel ou biblioteca crítica, planeje o reboot e valide depois:

```bash
sudo reboot
```

Após retornar:

```bash
cd ~/homelab-infrastructure-server
./scripts/healthcheck.sh
```

## Atualizações automáticas de segurança

A política já foi auditada e validada:

- `unattended-upgrades.service` ativo;
- `apt-daily.timer` ativo;
- `apt-daily-upgrade.timer` ativo;
- atualização diária das listas APT habilitada;
- unattended upgrade diário habilitado;
- pockets de segurança permitidos;
- reboot automático não habilitado;
- execução real registrada em `/var/log/unattended-upgrades/unattended-upgrades.log`.

Audite periodicamente:

```bash
systemctl status unattended-upgrades --no-pager
systemctl status apt-daily.timer --no-pager
systemctl status apt-daily-upgrade.timer --no-pager
sudo tail -n 50 /var/log/unattended-upgrades/unattended-upgrades.log
```

Reboots continuam sendo planejados e executados manualmente.

## SSH

A política de acesso remoto validada é:

```text
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
```

Auditoria:

```bash
sudo sshd -t
sudo sshd -T | grep -Ei 'passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|permitrootlogin'
```

Não altere ou remova a chave pública ativa sem manter uma sessão administrativa válida para recuperação.

## Atualização da stack Docker

O Diun **somente notifica** quando existem novas imagens.

Não existe Watchtower na arquitetura atual.

Antes de atualizar:

```bash
cd ~/homelab-infrastructure-server
./scripts/backup.sh
```

Atualização da stack completa:

```bash
./scripts/update-stack.sh
```

Preferencialmente, em serviços críticos, atualize um por vez e valide antes de seguir.

## AdGuard Home

Depois de atualizar:

```bash
dig @192.168.100.2 ubuntu.com
docker logs --tail 100 adguardhome
sudo ss -lunp | grep -E ':(53|67)\b'
```

Valide também DHCP, Query Log e login administrativo.

## Atualizar root hints do Unbound

```bash
sudo curl -fsSL https://www.internic.net/domain/named.cache \
  -o /var/lib/unbound/root.hints
sudo chown unbound:unbound /var/lib/unbound/root.hints
sudo unbound-checkconf
sudo systemctl restart unbound
```

Depois:

```bash
dig @127.0.0.1 -p 5335 ubuntu.com
dig @192.168.100.2 ubuntu.com
```

## Limpeza segura do Docker

Analise primeiro:

```bash
docker system df
```

Remova somente imagens não utilizadas:

```bash
docker image prune -f
```

Não use `docker system prune --volumes` no HomeLab: volumes contêm dados persistentes dos serviços.

## Logs

```bash
journalctl --disk-usage
journalctl -u docker --since today
journalctl -u unbound --since today
docker logs --tail 100 adguardhome
docker logs --tail 100 diun
docker logs --tail 100 beszel-agent
```

Erros de armazenamento/USB:

```bash
sudo dmesg -T | grep -Ei 'usb|uas|reset|I/O error|buffer I/O|sd[a-z]'
```

## Controle de espaço

```bash
df -h /
df -h /srv/backup
sudo du -xhd1 /var | sort -h
docker system df
journalctl --disk-usage
```

Mantenha preferencialmente mais de 20% livre no armazenamento interno.

## Restic

Listar snapshots:

```bash
sudo bash -c 'source /etc/homelab-backup/restic.env; restic snapshots'
```

Verificação de integridade:

```bash
sudo bash -c 'source /etc/homelab-backup/restic.env; restic check'
```

O restore test mensal é automatizado, mas pode ser disparado manualmente:

```bash
sudo systemctl start homelab-restore-test.service
sudo journalctl -u homelab-restore-test.service --no-pager -n 100
```

## Checklist mensal

- [ ] timezone continua `America/Sao_Paulo` e NTP sincronizado;
- [ ] timers do HomeLab apresentam próximos disparos coerentes;
- [ ] Ubuntu e pacotes revisados;
- [ ] `unattended-upgrades` operacional;
- [ ] SSH continua aceitando chave e rejeitando senha;
- [ ] stack Docker revisada após notificações do Diun;
- [ ] snapshots Restic recentes;
- [ ] `last-success.txt` recente e com `status=success`;
- [ ] restore test recente com `RESTORE_TEST_OK.txt`;
- [ ] `restic check` sem erros;
- [ ] espaço interno superior a 20%;
- [ ] mídia de backup sem erros de I/O;
- [ ] Uptime Kuma sem incidentes não explicados;
- [ ] Beszel sem tendência anormal de CPU/RAM/temperatura/disco;
- [ ] nenhuma porta encaminhada no modem;
- [ ] credenciais e acessos administrativos revisados.
