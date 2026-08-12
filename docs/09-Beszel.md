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

A implantação é feita em duas etapas:

1. **Beszel Hub** em Docker, acessível somente na LAN em `192.168.100.2:8090`;
2. **Beszel Agent** local, conectado ao Hub por Unix socket.

O socket local evita expor a porta padrão do Agent na LAN quando Hub e Agent estão no mesmo servidor.

```text
Navegador LAN
     |
     v
Beszel Hub :8090
     |
     | Unix socket /beszel_socket/beszel.sock
     v
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
2. use um nome como `homelab`;
3. escolha a opção de Agent local;
4. copie a `KEY` e o `TOKEN` gerados pelo Hub;
5. não publique essas credenciais no GitHub.

Para este servidor, o Agent será configurado em Docker usando o volume compartilhado `beszel_socket` e:

```text
LISTEN=/beszel_socket/beszel.sock
```

No campo Host / IP do sistema no Hub, use:

```text
/beszel_socket/beszel.sock
```

A configuração definitiva do Agent deve usar os valores gerados pelo próprio Hub e será aplicada somente depois da criação do sistema.

## Docker

O Agent precisa de acesso somente leitura ao socket Docker para coletar métricas dos containers:

```text
/var/run/docker.sock:/var/run/docker.sock:ro
```

O socket Docker é altamente privilegiado mesmo quando montado como somente leitura. Não exponha o Agent à Internet e use apenas a imagem oficial.

## Persistência

O Hub usa:

```text
beszel_data:/beszel_data
```

O socket compartilhado usa:

```text
beszel_socket:/beszel_socket
```

Inclua o volume `beszel_data` na política de backup antes de considerar o serviço em produção.

## Firewall

Permita o dashboard apenas na LAN:

```bash
sudo ufw allow from 192.168.100.0/24 to any port 8090 proto tcp comment 'Beszel LAN'
```

Não crie port forwarding no Huawei para a porta `8090`.

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
- containers `adguardhome`, `portainer`, `uptime-kuma`, `diun` e `beszel`.

## Alertas iniciais sugeridos

Use limites conservadores e ajuste depois de observar o baseline do servidor:

- CPU alta sustentada;
- memória acima de 85%;
- disco acima de 80%;
- temperatura elevada;
- sistema offline.

Evite alertas muito agressivos antes de coletar pelo menos alguns dias de histórico.

## Segurança

- dashboard somente na LAN;
- nenhuma porta do Beszel encaminhada no modem;
- senha administrativa exclusiva;
- `KEY` e `TOKEN` nunca versionados;
- backup do volume `beszel_data`;
- atualizações revisadas manualmente após notificação do Diun.
