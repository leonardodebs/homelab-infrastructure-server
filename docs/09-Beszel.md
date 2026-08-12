# 09B — Beszel — Monitoramento de recursos do host

O **Beszel** complementa o Uptime Kuma.

- **Uptime Kuma** monitora disponibilidade de serviços e endpoints;
- **Beszel** monitora recursos do servidor e dos containers ao longo do tempo.

## Objetivo

Monitorar no Dell Wyse:

- CPU e load average;
- memória RAM e swap;
- uso e I/O de disco;
- tráfego de rede;
- temperatura e sensores disponíveis;
- uptime do host;
- uso de CPU, memória e rede por container Docker;
- alertas de CPU, memória, disco, banda, temperatura e indisponibilidade.

## Arquitetura adotada

A implantação usa dois containers:

1. **Beszel Hub**, acessível somente na LAN em `192.168.100.2:8090`;
2. **Beszel Agent**, no mesmo host, coletando as métricas e iniciando uma conexão WebSocket de saída para o Hub.

A operação final usa **WebSocket-only** no Agent. O servidor SSH interno do Agent é desativado com `DISABLE_SSH=true`, portanto nenhuma porta de entrada do Agent precisa ser aberta no firewall.

```text
Navegador LAN
     |
     v
Beszel Hub :8090
     ^
     | WebSocket iniciado pelo Agent
     |
Beszel Agent
     |
     +--> CPU / RAM / swap / load
     +--> disco / I/O
     +--> rede
     +--> temperatura
     +--> Docker / containers
```

## Etapa 1 — Subir o Hub

Atualize o clone:

```bash
cd ~/homelab-infrastructure-server
git pull
```

Baixe e inicie o Hub:

```bash
docker compose --env-file compose/.env -f compose/compose.yaml pull beszel
docker compose --env-file compose/.env -f compose/compose.yaml up -d beszel
```

Valide:

```bash
docker ps --filter name=beszel
docker logs --tail 100 beszel
curl -I http://192.168.100.2:8090
```

Acesse no navegador:

```text
http://192.168.100.2:8090
```

Crie a conta administrativa com senha exclusiva.

## Etapa 2 — Adicionar o próprio HomeLab

No painel do Beszel:

1. clique em **Add System**;
2. use o nome `homelab`;
3. escolha **Docker**;
4. gere/copie a `KEY` e o `TOKEN`;
5. não publique essas credenciais no GitHub.

As credenciais ficam somente em `compose/.env`, que é ignorado pelo Git.

Exemplo:

```text
SERVER_IP=192.168.100.2
BESZEL_KEY=<chave publica>
BESZEL_TOKEN=<token>
```

## Agent em WebSocket-only

O Agent usa:

```text
HUB_URL=http://192.168.100.2:8090
DISABLE_SSH=true
```

Com `HUB_URL`, o próprio Agent inicia a conexão WebSocket para o Hub. Como `DISABLE_SSH=true`, a porta padrão `45876` não é necessária para este HomeLab e não deve ser liberada no UFW.

Suba o Agent:

```bash
docker compose --env-file compose/.env -f compose/compose.yaml pull beszel-agent
docker compose --env-file compose/.env -f compose/compose.yaml up -d beszel-agent
```

Valide:

```bash
docker ps --filter name=beszel-agent
docker logs --tail 100 beszel-agent
docker inspect --format '{{.State.Health.Status}}' beszel-agent
```

Nos logs, a evidência principal é:

```text
WebSocket connected host=192.168.100.2:8090
```

## Docker

O Agent precisa de acesso somente leitura ao socket Docker para coletar métricas dos containers:

```text
/var/run/docker.sock:/var/run/docker.sock:ro
```

O socket Docker é altamente privilegiado mesmo quando montado como somente leitura. Não exponha o Agent à Internet e use apenas a imagem oficial.

## Filesystem raiz

No Wyse, o filesystem raiz está sobre LVM e corresponde ao device `dm-0`:

```text
/dev/mapper/ubuntu--vg-ubuntu--lv -> dm-0
```

O Agent é configurado explicitamente com:

```text
FILESYSTEM=dm-0
```

Isso evita depender da autodetecção do filesystem dentro do container.

Valide no host:

```bash
df -h /
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
```

O percentual mostrado no Beszel deve ser compatível com o uso real de `/`.

## Persistência

O Hub usa:

```text
beszel_data:/beszel_data
```

O Agent usa:

```text
beszel_agent_data:/var/lib/beszel-agent
```

Inclua `beszel_data` e `beszel_agent_data` na política de backup.

## Firewall

Permita apenas o dashboard do Hub na LAN:

```bash
sudo ufw allow from 192.168.100.0/24 to any port 8090 proto tcp comment 'Beszel LAN'
```

Não abra `45876/tcp` e não crie port forwarding no Huawei.

## Monitoramento recomendado

Depois que o Agent estiver conectado, valide no dashboard:

- CPU;
- RAM;
- swap;
- load average;
- filesystem `/`;
- disk I/O;
- interface `enxd037454bc6c1`;
- temperatura;
- containers `adguardhome`, `portainer`, `uptime-kuma`, `beszel`, `beszel-agent` e `diun`.

## Alertas iniciais sugeridos

Use limites conservadores e ajuste depois de observar o baseline do servidor:

- CPU acima de 90% por 10 minutos;
- memória acima de 85% por 10 minutos;
- disco acima de 80%;
- temperatura acima de 75 °C por 5 minutos;
- load average elevado de forma sustentada;
- sistema offline.

Evite alertas muito agressivos antes de coletar pelo menos alguns dias de histórico.

## Segurança

- dashboard somente na LAN;
- Agent em WebSocket-only com `DISABLE_SSH=true`;
- nenhuma porta do Agent exposta;
- nenhuma porta do Beszel encaminhada no modem;
- senha administrativa exclusiva;
- `KEY` e `TOKEN` nunca versionados;
- backup dos volumes `beszel_data` e `beszel_agent_data`;
- atualizações revisadas manualmente após notificação do Diun.
