# 10 — Beszel — Monitoramento de recursos do host

O **Beszel** complementa o Uptime Kuma:

- **Uptime Kuma** monitora disponibilidade de serviços e endpoints;
- **Beszel** monitora recursos do servidor e containers ao longo do tempo.

## Objetivo

Monitorar no Dell Wyse:

- CPU e load average;
- memória RAM e swap;
- uso e I/O de disco;
- tráfego de rede;
- temperatura e sensores disponíveis;
- uptime do host;
- CPU, memória e rede por container Docker;
- alertas de capacidade e indisponibilidade.

## Arquitetura adotada

A implantação usa dois containers:

1. **Beszel Hub**, disponível na LAN em `192.168.100.2:8090`;
2. **Beszel Agent**, no mesmo host, iniciando uma conexão WebSocket de saída para o Hub.

O Agent opera em **WebSocket-only** com `DISABLE_SSH=true`. A porta padrão `45876` não é publicada nem liberada no UFW.

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

## Hub

```bash
cd ~/homelab-infrastructure-server
docker compose --env-file compose/.env -f compose/compose.yaml up -d beszel
```

Acesso:

```text
http://192.168.100.2:8090
```

Valide:

```bash
docker ps --filter name=beszel
docker logs --tail 100 beszel
curl -I http://192.168.100.2:8090
```

## Credenciais do Agent

No painel, adicione o sistema `homelab` e gere `KEY` e `TOKEN`.

Essas credenciais ficam somente em `compose/.env`, ignorado pelo Git:

```text
SERVER_IP=192.168.100.2
BESZEL_KEY=<não versionar>
BESZEL_TOKEN=<não versionar>
```

## Agent em WebSocket-only

Configuração principal:

```text
HUB_URL=http://192.168.100.2:8090
DISABLE_SSH=true
FILESYSTEM=dm-0
```

Suba e valide:

```bash
docker compose --env-file compose/.env -f compose/compose.yaml up -d beszel-agent
docker ps --filter name=beszel-agent
docker logs --tail 100 beszel-agent
docker inspect --format '{{.State.Health.Status}}' beszel-agent
```

A evidência principal nos logs é uma conexão WebSocket bem-sucedida com o Hub.

## Docker socket

O Agent usa:

```text
/var/run/docker.sock:/var/run/docker.sock:ro
```

Mesmo somente leitura, o Docker socket é sensível. Não exponha o Agent à Internet e não publique a porta 45876.

## Filesystem raiz

O filesystem raiz do Wyse usa LVM e é observado pelo Agent como `dm-0`:

```text
/dev/mapper/ubuntu--vg-ubuntu--lv -> dm-0
```

Valide no host:

```bash
df -h /
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
```

O percentual exibido pelo Beszel deve ser compatível com `df -h /`.

## Persistência e backup

Volumes:

```text
homelab_beszel_data
homelab_beszel_agent_data
```

Ambos são incluídos no Restic.

## Monitoramento atual

O dashboard deve exibir métricas do host e dos containers:

- `adguardhome`;
- `portainer`;
- `uptime-kuma`;
- `beszel`;
- `beszel-agent`;
- `diun`;
- `homelab-web`.

## Alertas sugeridos

Ajuste depois de observar o baseline:

- CPU acima de 90% por 10 minutos;
- memória acima de 85% por 10 minutos;
- disco acima de 80%;
- temperatura acima de 75 °C por 5 minutos;
- load elevado de forma sustentada;
- sistema offline.

## Segurança

- dashboard somente na LAN;
- Agent WebSocket-only;
- nenhuma porta do Agent exposta;
- nenhuma porta encaminhada no modem;
- senha administrativa exclusiva;
- `KEY` e `TOKEN` nunca versionados;
- volumes incluídos no backup;
- atualizações revisadas manualmente após notificação do Diun.

## Estado atual

- [x] Hub disponível em `:8090`;
- [x] Agent saudável e conectado via WebSocket;
- [x] SSH interno do Agent desativado;
- [x] filesystem raiz monitorado;
- [x] métricas de host e containers validadas;
- [x] volumes incluídos no Restic.
