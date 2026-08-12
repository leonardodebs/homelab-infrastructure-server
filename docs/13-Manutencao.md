# 13 — Manutenção

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

## Backup

O backup já é agendado por systemd. Para validar o último sucesso:

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

Audite periodicamente:

```bash
systemctl status unattended-upgrades --no-pager
systemctl status apt-daily.timer --no-pager
systemctl status apt-daily-upgrade.timer --no-pager
```

O objetivo é permitir patches de segurança automáticos sem reboot automático não supervisionado.

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

- [ ] Ubuntu e pacotes revisados;
- [ ] `unattended-upgrades` operacional;
- [ ] stack Docker revisada após notificações do Diun;
- [ ] snapshots Restic recentes;
- [ ] restore test recente com `RESTORE_TEST_OK.txt`;
- [ ] `restic check` sem erros;
- [ ] espaço interno superior a 20%;
- [ ] mídia de backup sem erros de I/O;
- [ ] Uptime Kuma sem incidentes não explicados;
- [ ] Beszel sem tendência anormal de CPU/RAM/temperatura/disco;
- [ ] nenhuma porta encaminhada no modem;
- [ ] credenciais e acessos administrativos revisados.
