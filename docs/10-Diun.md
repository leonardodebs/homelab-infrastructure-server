# 10 — Diun

O **Diun (Docker Image Update Notifier)** verifica se as imagens dos containers monitorados receberam novas versões ou novos digests no registry.

A política do HomeLab é **detectar e revisar atualizações, sem atualizar containers automaticamente**. Isso reduz o risco de indisponibilidade em serviços críticos como DNS e DHCP.

## Por que Diun

O projeto original `containrrr/watchtower` foi arquivado pelos mantenedores em dezembro de 2025. Por isso, este HomeLab não usa mais Watchtower.

O Diun permanece ativo e é adequado ao objetivo deste projeto: avisar que existe uma imagem nova e deixar a atualização para uma janela de manutenção controlada.

## Política adotada

O Diun monitora, via labels, estas imagens:

- Portainer;
- AdGuard Home;
- Uptime Kuma;
- o próprio Diun.

O Diun **não recria nem atualiza containers automaticamente**.

O Unbound continua sendo atualizado pelo APT do Ubuntu.

## Agendamento

A stack usa:

```text
DIUN_WATCH_SCHEDULE=0 4 * * 0
```

Isso executa a checagem aos domingos às 04:00 no fuso `America/Sao_Paulo`.

Também é mantido:

```text
DIUN_WATCH_RUNONSTARTUP=true
DIUN_WATCH_JITTER=30s
```

Assim, o Diun faz uma checagem ao iniciar e aplica pequeno jitter às execuções agendadas.

## Instalação

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

O container deve aparecer como `Up` e, após o período inicial do healthcheck, como `healthy`.

## Containers monitorados

A stack usa a label:

```text
diun.enable=true
```

O provider Docker está configurado com:

```text
DIUN_PROVIDERS_DOCKER_WATCHBYDEFAULT=false
```

Portanto apenas containers explicitamente marcados são analisados.

## Atualização manual

Quando o Diun indicar nova imagem, revise release notes e faça a atualização manual do serviço correspondente.

Exemplo genérico:

```bash
cd ~/homelab-infrastructure-server
./scripts/backup.sh

docker compose --env-file compose/.env -f compose/compose.yaml pull NOME_DO_SERVICO
docker compose --env-file compose/.env -f compose/compose.yaml up -d NOME_DO_SERVICO
docker logs --tail 100 NOME_DO_SERVICO
```

Para AdGuard Home, valide obrigatoriamente após a atualização:

```bash
dig @192.168.100.2 ubuntu.com
sudo ss -lunp | grep -E ':(53|67)\b'
```

## Notificações

A primeira implantação usa os logs do Diun. Notificações externas podem ser adicionadas depois por e-mail, ntfy, Gotify, Telegram ou outro notifier suportado.

Não armazene tokens, senhas ou webhooks diretamente no repositório.

## Segurança

O Diun precisa consultar a API Docker e, por isso, acessa `/var/run/docker.sock`.

Esse socket é altamente privilegiado. O container deve ser obtido apenas da imagem oficial e não deve publicar portas na LAN ou na Internet.

## Cuidados

- Diun não substitui backup;
- não automatizar atualização de DNS/DHCP;
- revisar changelog antes de atualizar;
- atualizar um serviço por vez;
- validar Uptime Kuma, DNS, DHCP e acesso administrativo após mudanças;
- manter a janela de manutenção fora do horário de uso intenso.
