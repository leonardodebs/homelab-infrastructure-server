# 13 — Manutenção

## Rotina semanal

```bash
./scripts/healthcheck.sh
./scripts/backup.sh
docker ps
docker system df
df -h /
```

Verifique:

- espaço livre;
- containers reiniciando;
- falhas no Uptime Kuma;
- consultas DNS anormais;
- temperatura e estabilidade do equipamento.

## Atualizações do Ubuntu

```bash
sudo apt update
apt list --upgradable
sudo apt upgrade -y
sudo apt autoremove --purge -y
```

Se houver atualização de kernel:

```bash
sudo reboot
```

Depois:

```bash
./scripts/healthcheck.sh
```

## Atualização da stack

O script cria backup antes de atualizar:

```bash
./scripts/update-stack.sh
```

O AdGuard Home permanece fora do Watchtower e deve ser atualizado manualmente.

## Atualizar root hints do Unbound

```bash
sudo curl -fsSL https://www.internic.net/domain/named.cache \
  -o /var/lib/unbound/root.hints
sudo chown unbound:unbound /var/lib/unbound/root.hints
sudo unbound-checkconf
sudo systemctl restart unbound
```

## Limpeza segura do Docker

Verifique primeiro:

```bash
docker system df
```

Remova somente imagens não utilizadas:

```bash
docker image prune -f
```

Não use `docker system prune --volumes` sem entender o impacto.

## Logs

```bash
journalctl --disk-usage
journalctl -u docker --since today
journalctl -u unbound --since today
docker logs --tail 100 adguardhome
```

## Controle de espaço

```bash
df -h
sudo du -xhd1 /var | sort -h
sudo du -xhd1 /opt | sort -h
docker system df
```

## Checklist mensal

- [ ] backup copiado para outro dispositivo;
- [ ] restauração documentada;
- [ ] Ubuntu atualizado;
- [ ] serviços validados após atualização;
- [ ] root hints atualizados;
- [ ] espaço livre superior a 20%;
- [ ] nenhuma porta exposta no modem;
- [ ] senhas e acessos revisados.
