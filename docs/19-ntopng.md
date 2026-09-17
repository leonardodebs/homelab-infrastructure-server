# 19 — ntopng e observabilidade de rede

## Objetivo

O `ntopng` foi implantado para acrescentar visibilidade de tráfego de rede ao HomeLab, complementando o monitoramento de disponibilidade do Uptime Kuma, as métricas de host/containers no Grafana e os registros DNS do AdGuard Home.

## Estado atual

- ntopng instalado nativamente no Ubuntu Server;
- serviço gerenciado pelo systemd;
- interface web disponível somente na LAN;
- porta TCP `3000` liberada no UFW para a rede `192.168.15.0/24`;
- monitoramento associado à interface Ethernet principal do HomeLab;
- rede local `192.168.15.0/24` reconhecida como rede interna via `-m=` em `/etc/ntopng/ntopng.conf` (corrigido em 17/09/2026 — ver incidente abaixo);
- dashboard validado e operacional;
- desde o [capítulo 20](20-Caddy-TLS-Local.md), a porta pública `3000` é servida com TLS confiável pelo Caddy; o ntopng em si migrou seu `--http-port` (`-w=` em `/etc/ntopng/ntopng.conf`) para `3300`.

### Incidente: "top talkers" absurdos no Grafana (17/09/2026)

O `-m` (local-networks) do ntopng ficou com a faixa **antiga** (`192.168.100.0/24`) depois da migração de rede para `192.168.15.0/24` — esse arquivo é config nativa, fora do repositório Git, e escapou de todas as buscas por IP feitas na época. Com o `-m` errado, o ntopng deixou de reconhecer qualquer tráfego como "local" e passou a classificar tráfego normal (LAN, entre containers) como se fosse tráfego de/para a Internet, inflando artificialmente os números de "bytes enviados" no painel `Rede - Top talkers` do Grafana (chegou a mostrar >1 TiB enviados em 24h pelo Dell, quando os contadores reais da interface mostravam poucos GB desde o boot).

Diagnóstico: comparar o total real da interface (`ip -s link show lan0` ou `cat /sys/class/net/lan0/statistics/tx_bytes`) com o número do painel — se o painel mostra ordens de magnitude a mais que o contador real, é sinal de classificação errada, não de tráfego real.

Correção:

```bash
sudo sed -i 's/^-m=192\.168\.100\.0\/24/-m=192.168.15.0\/24/' /etc/ntopng/ntopng.conf
sudo systemctl restart ntopng
grep '^-m=' /etc/ntopng/ntopng.conf
```

Qualquer futura mudança de faixa de IP deve incluir a checagem de `-m=` em `/etc/ntopng/ntopng.conf` explicitamente — é o único lugar do projeto onde o IP local vive fora do Git.

### Incidente: erros 403 do ntopng ao exportar para o InfluxDB (17/09/2026)

Durante a investigação do incidente anterior, os logs do ntopng (`journalctl -u ntopng`) mostraram erros repetidos de `403` ao tentar gravar métricas no InfluxDB (`monitoring_influxdb_data`, container `influxdb` no Lenovo `192.168.15.3`).

Causa: o usuário `ntopng` no InfluxDB tinha apenas permissão de leitura/escrita no banco `ntopng` (`GRANT ... ON ntopng`), mas a exportação do ntopng também precisa gerenciar retention policies/continuous queries e ler o banco interno `_internal` — operações que exigem privilégio de administrador do cluster InfluxDB (não apenas acesso ao banco).

Diagnóstico:

```bash
docker exec influxdb influx -username admin -password '<senha>' -execute 'SHOW USERS'
# usuário "ntopng" aparecia com admin=false
```

Correção (executada no Lenovo, fora deste repositório — é estado do InfluxDB, não arquivo versionado):

```bash
docker exec influxdb influx -username admin -password '<senha>' -execute 'GRANT ALL PRIVILEGES TO "ntopng"'
```

Validação: `SHOW USERS` passou a mostrar `ntopng true`; após `systemctl restart ntopng` no Dell, os logs pararam de mostrar erros `403` e o InfluxDB passou a receber as measurements (`host:packets`, `host:active_flows`, etc.) normalmente.

Nota de segurança: como parte da revisão desse incidente, as senhas do InfluxDB usadas nos comandos de diagnóstico foram consideradas expostas (apareceram em texto puro na sessão) e a senha do usuário `admin` deve ser rotacionada — ver `docker/monitoring/.env` no repositório `homelab-automation-server` (Lenovo).

Acesso administrativo:

```text
https://192.168.15.2:3000
```

Porta interna real (usada pelo Caddy): `192.168.15.2:3300`.

## Papel na observabilidade

A arquitetura atual separa responsabilidades:

| Ferramenta | Responsabilidade |
|---|---|
| AdGuard Home | consultas DNS, DHCP e políticas por cliente |
| Uptime Kuma | disponibilidade de serviços e conectividade |
| Prometheus + Grafana | CPU, RAM, disco, temperatura, rede do host e containers |
| ntopng | análise de tráfego, hosts, protocolos e fluxos visíveis pela interface monitorada |

Essa combinação permite analisar tanto a saúde do servidor quanto o comportamento da rede.

## Limitação arquitetural atual

O Dell Wyse não é o gateway padrão da residência. O gateway continua sendo o Huawei em `192.168.15.1`.

Por esse motivo, o ntopng não deve ser interpretado como sensor de todo o tráfego da LAN. Ele observa principalmente o tráfego que efetivamente chega ou passa pela interface do próprio HomeLab.

Para obter visibilidade completa entre todos os clientes e a Internet seria necessária uma arquitetura adicional, como:

- transformar um equipamento dedicado em gateway/firewall;
- utilizar switch gerenciável com SPAN/port mirroring;
- utilizar exportação de fluxos, quando suportada pela infraestrutura de rede.

## Segurança

A interface web do ntopng permanece restrita à LAN. Não existe port forwarding no modem para a porta `3000`.

O acesso deve seguir a mesma política das demais interfaces administrativas do HomeLab: somente rede local confiável, credenciais administrativas próprias e nenhuma exposição direta à Internet.

## Validação operacional

A implantação foi considerada válida após:

- inicialização correta do serviço;
- acesso ao dashboard pela LAN;
- visualização da interface monitorada;
- reconhecimento de hosts e fluxos observáveis;
- aplicação de filtros no dashboard;
- liberação controlada da porta `3000/tcp` no UFW.

## Evolução futura

Caso seja adicionado um terceiro mini PC dedicado a gateway/firewall, o ntopng poderá ganhar uma posição mais estratégica na observabilidade da rede, pois o tráfego de entrada e saída poderá ser concentrado nesse caminho.

Até essa mudança ocorrer, o ntopng deve ser tratado como ferramenta complementar de análise do HomeLab, e não como captura integral de toda a LAN.
