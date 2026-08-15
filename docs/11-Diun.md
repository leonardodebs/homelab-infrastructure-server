# 11 — Diun

O **Diun (Docker Image Update Notifier)** verifica se as imagens dos containers monitorados receberam novos digests ou versões no registry.

A política do HomeLab é **detectar e revisar atualizações, sem atualizar containers automaticamente**. Isso reduz risco em serviços críticos como DNS e DHCP.

## Política adotada

A stack usa `diun.enable=true` nos serviços monitorados.

Atualmente o Diun acompanha:

- Portainer;
- AdGuard Home;
- Uptime Kuma;
- Beszel Hub;
- Beszel Agent;
- HomeLab Web/Nginx;
- o próprio Diun.

O Unbound não é containerizado e continua sob gerenciamento do APT do Ubuntu.

## Por que não há Watchtower

O HomeLab não usa Watchtower. A estratégia atual separa **detecção** de **execução da atualização**: o Diun avisa, e a atualização é aplicada manualmente depois de revisão e backup.

Qualquer referência antiga ao Watchtower deve ser considerada obsoleta.

## Agendamento

Configuração atual:

```text
DIUN_WATCH_SCHEDULE=0 4 * * 0
DIUN_WATCH_RUNONSTARTUP=true
DIUN_WATCH_JITTER=30s
TZ=America/Sao_Paulo
```

A checagem agendada ocorre aos domingos às 04:00, com pequeno jitter.

## Instalação/recriação

```bash
cd ~/homelab-infrastructure-server
git pull

docker compose --env-file compose/.env -f compose/compose.yaml pull diun
docker compose --env-file compose/.env -f compose/compose.yaml up -d diun
```

## Validação

```bash
docker ps --filter name=diun
docker logs --tail 100 diun
docker inspect --format '{{.State.Health.Status}}' diun
```

O container deve ficar `healthy` depois do período inicial do healthcheck.

Para confirmar os labels atuais:

```bash
docker ps -q | xargs -r docker inspect \
  --format '{{.Name}} {{index .Config.Labels "diun.enable"}}'
```

## Atualização manual

Antes de atualizar a stack inteira:

```bash
cd ~/homelab-infrastructure-server
./scripts/backup.sh
./scripts/update-stack.sh
```

Para atualizar somente um serviço:

```bash
docker compose --env-file compose/.env -f compose/compose.yaml pull SERVICO
docker compose --env-file compose/.env -f compose/compose.yaml up -d SERVICO
docker logs --tail 100 SERVICO
```

Atualize um serviço por vez quando a mudança for sensível.

### AdGuard Home

Depois de qualquer atualização do AdGuard:

```bash
dig @192.168.100.2 ubuntu.com
sudo ss -lunp | grep -E ':(53|67)\b'
docker logs --tail 100 adguardhome
```

Confirme também DHCP e login administrativo.

## Notificações

A implantação atual usa os logs do Diun como evidência. Notificações externas podem ser adicionadas futuramente.

Não armazene tokens, senhas ou webhooks diretamente no repositório.

## Segurança

O Diun acessa `/var/run/docker.sock`, portanto:

- use somente imagem confiável/oficial;
- não publique portas para o Diun;
- não exponha o Docker socket fora do host;
- mantenha atualizações manuais e auditáveis.

## Estado atual

- [x] Diun saudável;
- [x] execução no startup habilitada;
- [x] agenda semanal configurada;
- [x] sete imagens da stack marcadas para monitoramento;
- [x] atualização automática desabilitada por desenho.
