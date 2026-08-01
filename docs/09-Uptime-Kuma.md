# 09 — Uptime Kuma

O Uptime Kuma monitora disponibilidade e tempo de resposta dos componentes do HomeLab.

## Instalação

```bash
cd ~/homelab-infrastructure-server
docker compose --env-file compose/.env -f compose/compose.yaml up -d uptime-kuma
```

Acesse:

```text
http://192.168.100.10:3001
```

Crie uma conta administrativa com senha exclusiva.

## Monitores recomendados

1. **Gateway Huawei**
   - Tipo: Ping
   - Host: `192.168.100.1`
   - Intervalo: 60 segundos

2. **AdGuard DNS**
   - Tipo: DNS
   - Resolver: `192.168.100.10`
   - Hostname de teste: `ubuntu.com`
   - Porta: `53`

3. **Portainer**
   - Tipo: HTTP(s)
   - URL: `https://192.168.100.10:9443`
   - Aceitar certificado autoassinado apenas para esse monitor.

4. **AdGuard Web**
   - Tipo: HTTP
   - URL: `http://192.168.100.10`

5. **Internet**
   - Tipo: Ping
   - Host: `1.1.1.1`

## Validação

```bash
docker ps --filter name=uptime-kuma
docker logs --tail 100 uptime-kuma
curl -I http://192.168.100.10:3001
```

## Backup

Os dados ficam no volume `uptime_kuma_data` e são incluídos no script `scripts/backup.sh`.

## Segurança

- não encaminhar a porta 3001 no modem;
- manter acesso somente na LAN;
- criar notificações apenas depois de validar os monitores;
- evitar credenciais reutilizadas.
