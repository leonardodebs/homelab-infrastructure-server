# 06 — AdGuard Home

O AdGuard Home será executado em modo `host` para usar DNS, DHCP e identificar corretamente os clientes.

## Pré-requisitos

- IP estático do Wyse configurado;
- Unbound instalado e respondendo em `127.0.0.1:5335`;
- porta 53 livre no host;
- DHCP do modem ainda ativo durante os testes iniciais.

## Verificar porta 53

```bash
sudo ss -lntup | grep ':53 '
```

Em Ubuntu Server, o `systemd-resolved` pode usar um stub local em `127.0.0.53`, que não costuma impedir o AdGuard de escutar no IP da LAN. Se houver conflito em `0.0.0.0:53`, investigue antes de continuar.

## Subir o container

```bash
cd ~/homelab-infrastructure-server
docker compose --env-file compose/.env -f compose/compose.yaml up -d adguardhome
```

Acesse a configuração inicial:

```text
http://192.168.100.10:3000
```

## Assistente inicial

Use:

- interface administrativa: `192.168.100.10`;
- porta administrativa final: `80` ou outra porta livre;
- servidor DNS: todas as interfaces, porta `53`;
- usuário e senha exclusivos.

Após concluir, o painel normalmente ficará em:

```text
http://192.168.100.10
```

## Upstream DNS

Em **Settings > DNS settings**, configure:

```text
127.0.0.1:5335
```

Remova upstreams públicos para garantir que as consultas permitidas usem o Unbound.

Bootstrap DNS pode permanecer vazio quando o upstream é um endereço IP local.

## Testar DNS antes de alterar DHCP

No próprio servidor:

```bash
dig @127.0.0.1 google.com
dig @192.168.100.10 google.com
```

No notebook, configure temporariamente o DNS manual como `192.168.100.10` e teste:

```powershell
nslookup google.com 192.168.100.10
nslookup doubleclick.net 192.168.100.10
```

## Listas de bloqueio

Comece de forma conservadora para evitar falsos positivos.

Sugestão inicial:

- AdGuard DNS filter, já disponível no painel;
- OISD Small ou OISD Big conforme necessidade;
- uma lista de malware reconhecida.

Evite empilhar várias listas que contêm os mesmos domínios. Monitore o Query Log e crie allowlists somente quando houver evidência de quebra.

## Clientes

Cadastre clientes por IP reservado ou MAC quando possível:

- notebook pessoal;
- notebook de trabalho;
- celulares;
- Smart TVs;
- outros dispositivos relevantes.

## Regras importantes

- não exponha o painel à Internet;
- não ative DHCP antes do capítulo 08;
- faça backup do volume antes de atualizar o container;
- mantenha o AdGuard fora das atualizações automáticas do Watchtower.

## Validação

```bash
docker ps --filter name=adguardhome
docker logs --tail 100 adguardhome
sudo ss -lntup | grep -E ':53 |:80 |:3000 '
dig @192.168.100.10 cloudflare.com
```

- [ ] painel acessível somente na LAN;
- [ ] consultas aparecem no Query Log;
- [ ] upstream aponta para `127.0.0.1:5335`;
- [ ] domínio de anúncio é bloqueado;
- [ ] domínio comum resolve normalmente.
