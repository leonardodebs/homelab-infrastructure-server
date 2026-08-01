# 10 — Watchtower

O Watchtower verifica imagens atualizadas e recria apenas containers marcados com o rótulo apropriado.

## Política adotada

Atualização automática permitida para:

- Portainer;
- Uptime Kuma.

Atualização automática desativada para:

- AdGuard Home, por ser DNS e DHCP crítico;
- Watchtower;
- Unbound, que é atualizado pelo APT do Ubuntu.

## Agendamento

A stack usa:

```text
WATCHTOWER_SCHEDULE=0 0 4 * * 0
```

Isso executa aos domingos às 04:00 no fuso `America/Sao_Paulo`.

## Instalação

```bash
cd ~/homelab-infrastructure-server
docker compose --env-file compose/.env -f compose/compose.yaml up -d watchtower
```

## Logs

```bash
docker logs --tail 100 watchtower
docker logs -f watchtower
```

## Teste manual sem atualizar

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower:latest \
  --run-once --monitor-only --label-enable
```

## Atualização de serviços críticos

Para atualizar AdGuard Home, execute manualmente após backup:

```bash
./scripts/backup.sh
docker compose --env-file compose/.env -f compose/compose.yaml pull adguardhome
docker compose --env-file compose/.env -f compose/compose.yaml up -d adguardhome
docker logs --tail 100 adguardhome
```

## Cuidados

- Watchtower não substitui backup;
- não usar tags experimentais;
- validar DNS e DHCP após atualização manual;
- manter a janela de manutenção fora do horário de uso intenso.
