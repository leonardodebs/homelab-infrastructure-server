# 11 — Diun

O **Diun (Docker Image Update Notifier)** verifica se as imagens dos containers monitorados receberam novos digests ou versões no registry.

A política do HomeLab é **detectar e revisar atualizações, sem atualizar containers automaticamente**. Isso reduz risco em serviços críticos como DNS e DHCP.

## Política adotada

A stack usa `diun.enable=true` nos serviços monitorados.

Atualmente o Diun acompanha:

- Portainer;
- AdGuard Home;
- Uptime Kuma;
- HomeLab Web/Nginx;
- Caddy;
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

O Diun envia e-mail por SMTP (Gmail) quando encontra uma imagem atualizada, além de continuar registrando tudo em log.

Configuração (`compose/compose.yaml`, serviço `diun`):

```text
DIUN_NOTIF_MAIL_HOST=smtp.gmail.com
DIUN_NOTIF_MAIL_PORT=587
DIUN_NOTIF_MAIL_SSL=false
DIUN_NOTIF_MAIL_USERNAME=leonardodebs@gmail.com
DIUN_NOTIF_MAIL_FROM=leonardodebs@gmail.com
DIUN_NOTIF_MAIL_TO=leonardodebs@gmail.com
DIUN_NOTIF_MAIL_PASSWORDFILE=/run/secrets/diun-mail-password
```

A senha **não fica em variável de ambiente nem no repositório** — segue o mesmo padrão já usado pelo Restic (`config/restic/restic-password`): um arquivo com permissão `600`, fora do git (`.gitignore`), montado somente leitura no container.

Gerar a senha de app do Gmail (conta precisa ter verificação em duas etapas ativa):

1. Acesse <https://myaccount.google.com/apppasswords> logado como `leonardodebs@gmail.com`.
2. Crie uma senha de app (qualquer nome, ex. "Diun HomeLab").
3. Copie o valor gerado (16 caracteres, sem espaços).

No servidor, crie o arquivo **sem deixar a senha no histórico do shell nem em nenhum chat**:

```bash
install -d -m 700 ~/homelab-infrastructure-server/config/diun
( umask 177; cat > ~/homelab-infrastructure-server/config/diun/mail-password )
# cole a senha de app, Enter, depois Ctrl+D
chmod 600 ~/homelab-infrastructure-server/config/diun/mail-password
```

Depois:

```bash
cd ~/homelab-infrastructure-server
git pull
docker compose --env-file compose/.env -f compose/compose.yaml up -d diun
docker logs --tail 50 diun
```

Erros de autenticação SMTP aparecem nos logs assim que o Diun tenta usar o notificador — se a senha de app estiver errada ou a conta sem 2FA, o log mostra a falha na primeira checagem (`DIUN_WATCH_RUNONSTARTUP=true` garante que isso é testado imediatamente).

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
