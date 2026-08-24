# 19 — ntopng e observabilidade de rede

## Objetivo

O `ntopng` foi implantado para acrescentar visibilidade de tráfego de rede ao HomeLab, complementando o monitoramento de disponibilidade do Uptime Kuma, as métricas de host/containers no Grafana e os registros DNS do AdGuard Home.

## Estado atual

- ntopng instalado nativamente no Ubuntu Server;
- serviço gerenciado pelo systemd;
- interface web disponível somente na LAN;
- porta TCP `3000` liberada no UFW para a rede `192.168.100.0/24`;
- monitoramento associado à interface Ethernet principal do HomeLab;
- rede local `192.168.100.0/24` reconhecida como rede interna;
- dashboard validado e operacional.

Acesso administrativo:

```text
http://192.168.100.2:3000
```

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

O Dell Wyse não é o gateway padrão da residência. O gateway continua sendo o Huawei em `192.168.100.1`.

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
