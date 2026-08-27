# 06 — AdGuard Home

O AdGuard Home roda em `network_mode: host` para fornecer DNS, DHCPv4 e identificação real dos clientes da LAN.

## Estado atual

```text
Web (público, via Caddy) : https://192.168.100.2 (porta 80, TLS confiável)
Web (interno real)       : http://192.168.100.2:8280
DNS                      : 192.168.100.2:53 TCP/UDP
DHCPv4                   : UDP/67
Upstream                 : 127.0.0.1:5335
Domínio                  : home.arpa
```

Desde o [capítulo 20](20-Caddy-TLS-Local.md), a interface web do AdGuard não fica mais diretamente na porta `80` — o `http.address` em `AdGuardHome.yaml` foi movido para `192.168.100.2:8280`, e o Caddy assumiu a porta `80` pública terminando TLS com certificado de IP confiável. A porta DNS (`53`) nunca foi alterada nessa migração.

Acesso de emergência (sem depender do Caddy nem do DNS local), via túnel SSH:

```bash
ssh -L 8280:192.168.100.2:8280 leonardo@192.168.100.2
```

Depois abra `http://127.0.0.1:8280` localmente.

O DHCP do Huawei está desativado e o AdGuard Home é o servidor DHCPv4 da rede.

## Subir/validar o container

```bash
cd ~/homelab-infrastructure-server
docker compose --env-file compose/.env -f compose/compose.yaml up -d adguardhome

docker ps --filter name=adguardhome
docker logs --tail 100 adguardhome
sudo ss -lntup | grep -E '(:53|:67|:80)\b'
```

O DNS deve escutar em `192.168.100.2:53`. O Unbound permanece somente em `127.0.0.1:5335`.

## Upstream DNS

Em **Settings > DNS settings**, o upstream da implantação é:

```text
127.0.0.1:5335
```

Upstreams públicos não são usados como fallback no desenho atual. Isso garante o fluxo:

```text
Cliente -> AdGuard Home -> Unbound -> DNS raiz/autoritativos
```

## Testes DNS

No servidor:

```bash
dig @127.0.0.1 -p 5335 ubuntu.com
dig @192.168.100.2 ubuntu.com
dig @192.168.100.2 doubleclick.net
```

No Windows:

```powershell
nslookup ubuntu.com 192.168.100.2
nslookup doubleclick.net 192.168.100.2
```

O domínio comum deve resolver normalmente. Um domínio bloqueado pode retornar `0.0.0.0`, `::` ou outra resposta de bloqueio conforme a configuração do AdGuard.

## Clientes e DHCP

O AdGuard identifica clientes usando leases DHCP/hostnames e registra as consultas no Query Log.

Configuração atual de referência:

```text
Gateway       : 192.168.100.1
Pool DHCPv4   : 192.168.100.50 - 192.168.100.200
Lease         : 86400 segundos
DNS entregue  : 192.168.100.2
Domínio local : home.arpa
DHCPv6        : desativado
```

Consulte `docs/08-DHCP.md` para o procedimento completo.

## Listas de bloqueio

Use abordagem conservadora:

- filtros nativos/AdGuard DNS filter;
- OISD conforme necessidade;
- listas de malware somente quando houver justificativa;
- Query Log para investigação de falsos positivos;
- allowlists pontuais em vez de desativar filtragem globalmente.

Evite empilhar várias listas altamente sobrepostas.

## Autenticação administrativa

A conta administrativa atual usa o usuário:

```text
leonardo
```

A senha não é documentada nem versionada.

Parâmetros de proteção atuais:

```yaml
auth_attempts: 5
block_auth_min: 3
```

Portanto, após tentativas inválidas suficientes, o login web é bloqueado temporariamente por 3 minutos.

Erros observados:

```text
403 invalid username or password
429 auth: blocked for ...
```

Isso afeta somente o painel administrativo; DNS e DHCP continuam operando.

### Trocar a senha com segurança

A senha é armazenada como hash bcrypt em `AdGuardHome.yaml`. Nunca publique o hash nem a senha.

1. Instale a ferramenta local, se necessário:

```bash
sudo apt install -y apache2-utils
```

2. Gere um novo hash sem colocar a senha no histórico:

```bash
HASH="$(htpasswd -B -C 10 -n leonardo | cut -d: -f2-)"
```

3. Descubra o volume de configuração:

```bash
CONF_DIR="$(docker volume inspect -f '{{.Mountpoint}}' homelab_adguard_conf)"
CFG="$CONF_DIR/AdGuardHome.yaml"
```

4. Pare o AdGuard e faça backup do YAML:

```bash
docker stop adguardhome
sudo cp -a "$CFG" "$CFG.bak-$(date +%Y%m%d-%H%M%S)"
```

5. Substitua somente o hash do usuário e, se necessário, os parâmetros de autenticação. Faça a edição com o serviço parado.

6. Inicie novamente:

```bash
docker start adguardhome
unset HASH
```

7. Valide o login uma única vez e evite tentativas repetidas se houver erro.

## Segurança

- painel somente na LAN;
- nenhuma porta do AdGuard encaminhada no modem;
- usuário e senha exclusivos;
- hash/senha nunca versionados;
- configuração persistente incluída no Restic;
- atualizações notificadas pelo Diun e aplicadas manualmente após backup.

## Validação concluída

- [x] painel acessível na LAN;
- [x] DNS em `192.168.100.2:53`;
- [x] consultas aparecem no Query Log;
- [x] upstream somente `127.0.0.1:5335`;
- [x] domínio de anúncio bloqueado;
- [x] domínio comum resolve normalmente;
- [x] DHCPv4 ativo no AdGuard;
- [x] login administrativo validado após redefinição de senha;
- [x] `auth_attempts: 5` e `block_auth_min: 3` aplicados.
