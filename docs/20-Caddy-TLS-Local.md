# 20 — Caddy e TLS local

## Objetivo

Servir Portainer, AdGuard Home, Uptime Kuma, o site estático e o ntopng com HTTPS confiável, tanto por hostname (`https://*.home.arpa`) quanto pelo IP direto, usando um único reverse proxy (Caddy) e uma CA local emitida automaticamente por ele mesmo.

## Como funciona

O Caddy roda em `network_mode: host` (mesmo modelo do AdGuard) e assumiu as portas públicas que antes pertenciam diretamente a cada serviço. Cada serviço migrou para uma porta interna, ainda vinculada a `192.168.100.2` (não `127.0.0.1`), porque o Uptime Kuma monitora esses serviços pela rede Docker e precisa continuar alcançando-os por IP.

| Serviço | Porta pública HTTPS (Caddy) | Porta interna real |
|---|---|---|
| AdGuard Home | `8443` (a `80` continua HTTP puro — ver nota abaixo) | `192.168.100.2:8280` |
| ntopng | `3000` | `192.168.100.2:3300` |
| Uptime Kuma | `3001` | `192.168.100.2:3101` |
| HomeLab Web | `8080` | `192.168.100.2:8180` |
| Portainer | `9443` | `192.168.100.2:9444` |

Além disso, o Caddy escuta `443` para os hostnames `*.home.arpa` (`portainer`, `adguard`, `kuma`, `web`, `ntop`).

**Certificado por IP exige SAN de IP.** O motivo do Portainer sempre mostrar "Não seguro" mesmo com HTTPS é que o certificado autoassinado dele tem `IP Address: 0.0.0.0` como SAN — não bate com `192.168.100.2`. O Caddy 2.11+ emite certificados com SAN de IP pela CA interna quando o bloco do Caddyfile é endereçado pelo próprio IP:porta.

**Limitação real do Caddy na porta 80**: o Caddy trata a porta `80` como convenção fixa de HTTP puro e ignora silenciosamente qualquer diretiva `tls` colocada num bloco endereçado por `IP:80` — o certificado nunca é aplicado e a porta continua em texto puro (confirmado: logs mostravam "HTTP/2 skipped... requires TLS" e a resposta chegava sem criptografia mesmo com `tls internal` no bloco). Por isso o AdGuard Home ganhou uma porta HTTPS alternativa (`8443`) em vez de usar a `80` — a `80` continua exatamente como sempre foi (HTTP puro, redirecionando para `/login.html`). Quem quiser cadeado no AdGuard usa `https://192.168.100.2:8443` ou `https://adguard.home.arpa`.

DNS (porta `53`) nunca é alterado por nada neste capítulo.

**Portainer e CSRF atrás do proxy.** Por padrão, o `reverse_proxy` do Caddy reescreve o cabeçalho `Host` para o endereço do upstream (`192.168.100.2:9444`). O Portainer valida `Origin`/`Referer` contra esse `Host` recebido e rejeita login com `"Failed to validate Origin or Referer... origin invalid"` quando eles não batem com a porta pública (`9443`) que o navegador usou. A flag oficial `--trusted-origins` do Portainer **não resolve isso** — tem bug conhecido e sem correção que rejeita qualquer origem com porta ([portainer/portainer#12751](https://github.com/portainer/portainer/issues/12751)), derrubando o container com `"invalid url for trusted origin"`. A correção é forçar o Caddy a preservar o `Host` original do cliente:
```caddyfile
header_up Host {http.request.hostport}
```
Já aplicado nos dois blocos do Portainer no `compose/Caddyfile`.

## Pré-requisitos

- stack principal (`compose/compose.yaml`) implantada e saudável;
- AdGuard Home respondendo em `192.168.100.2:53`;
- acesso SSH ao servidor.

## 1. Subir o Caddy

```bash
cd ~/homelab-infrastructure-server
git pull
docker compose --env-file compose/.env -f compose/compose.yaml up -d caddy
docker logs --tail 50 caddy
```

> **Bind mount e `git pull`**: o Caddyfile é montado como arquivo único (`./Caddyfile:/etc/caddy/Caddyfile:ro`). Como o `git pull` substitui o arquivo (rename atômico), o bind mount do Docker fica preso ao inode antigo — `docker exec caddy caddy reload` sozinho **não** pega o conteúdo novo. Sempre rode `docker restart caddy` depois de um `git pull` que mude o Caddyfile.

## 2. Liberar a porta 443 no UFW

```bash
sudo ufw allow from 192.168.100.0/24 to any port 443 proto tcp comment 'Caddy TLS local LAN'
sudo ufw allow from 192.168.100.0/24 to any port 8443 proto tcp comment 'AdGuard HTTPS (Caddy) LAN'
```

As portas `80`, `3000`, `3001`, `8080` e `9443` já estavam liberadas para a LAN — não precisam de regra nova, só trocaram de "quem responde" (serviço direto → Caddy). `8443` é porta nova (HTTPS alternativo do AdGuard, já que a `80` não pode virar TLS — ver acima).

## 3. Mover cada serviço para a porta interna

Repita para cada serviço, testando antes de seguir pro próximo (evita quebrar tudo de uma vez se algo sair errado):

- **ntopng** (nativo, fora do compose): editar `-w=3000` para `-w=3300` em `/etc/ntopng/ntopng.conf` e `sudo systemctl restart ntopng`.
- **Uptime Kuma** e **HomeLab Web**: mudar as portas publicadas no `compose/compose.yaml` (`3001`→`3101`, `8080`→`8180`) e `docker compose up -d uptime-kuma homelab-web`.
- **Portainer**: mudar `9443`→`9444` no compose e `docker compose up -d portainer`.
- **AdGuard Home**: editar `http.address` em `AdGuardHome.yaml` de `192.168.100.2:80` para `192.168.100.2:8280` — **exige parar o container por alguns segundos** (mesmo processo que serve DNS), então guarde o túnel SSH de emergência antes:
  ```bash
  ssh -L 8280:192.168.100.2:8280 leonardo@192.168.100.2
  ```
  ```bash
  CONF="/var/lib/docker/volumes/homelab_adguard_conf/_data/AdGuardHome.yaml"
  sudo cp -a "$CONF" "$CONF.bak-$(date +%Y%m%d-%H%M%S)"
  docker stop adguardhome
  sudo sed -i 's/^  address: 192.168.100.2:80$/  address: 192.168.100.2:8280/' "$CONF"
  docker start adguardhome
  dig @192.168.100.2 cloudflare.com
  ```

A cada serviço migrado, atualize o bloco correspondente no `compose/Caddyfile` (adiciona um bloco `https://IP:porta { tls internal \n reverse_proxy IP:porta-interna }`) e rode `docker restart caddy`. **Exceção: porta 80** não aceita `tls` (ver limitação acima) — para o AdGuard, o bloco de HTTPS por IP usa a porta `8443`, não a `80`.

## 4. Ajustar as regras "Docker monitor" do UFW

O Uptime Kuma monitora os serviços pela rede Docker (`172.18.0.0/16`), então as regras que liberavam esse tráfego para as portas antigas precisam apontar para as novas:

```bash
sudo ufw allow from 172.18.0.0/16 to 192.168.100.2 port 8280 proto tcp comment 'Docker monitor AdGuard Web'
sudo ufw allow from 172.18.0.0/16 to 192.168.100.2 port 8180 proto tcp comment 'Docker monitor HomeLab Web'
sudo ufw allow from 172.18.0.0/16 to 192.168.100.2 port 9444 proto tcp comment 'Docker monitor Portainer'
sudo ufw delete allow from 172.18.0.0/16 to 192.168.100.2 port 80 proto tcp
sudo ufw delete allow from 172.18.0.0/16 to 192.168.100.2 port 8080 proto tcp
sudo ufw delete allow from 172.18.0.0/16 to 192.168.100.2 port 9443 proto tcp
```

## 5. Corrigir os monitores do Uptime Kuma

Os monitores **AdGuard Web**, **Portainer** e **HomeLab Web** apontavam para as portas públicas antigas, que agora servem TLS via Caddy — não vão mais responder a um GET HTTP simples. Edite cada um no painel do Kuma para a porta interna correspondente:

| Monitor | URL nova |
|---|---|
| AdGuard Web | `http://192.168.100.2:8280` |
| Portainer | `https://192.168.100.2:9444` |
| HomeLab Web | `http://192.168.100.2:8180` |

## 6. Cadastrar os nomes locais no AdGuard Home

Em **Filters → DNS rewrites**, adicione, todos apontando para `192.168.100.2`:

- `portainer.home.arpa`
- `adguard.home.arpa`
- `kuma.home.arpa`
- `web.home.arpa`
- `ntop.home.arpa`

## 7. Exportar e instalar a CA raiz

No servidor:

```bash
cd ~/homelab-infrastructure-server
bash scripts/export-caddy-ca.sh
```

Copie `caddy-root-ca.crt` para o Windows (ex.: `scp leonardo@192.168.100.2:~/homelab-infrastructure-server/caddy-root-ca.crt .`) e instale como raiz confiável **em uma sessão elevada** (o Windows exige confirmação por interface gráfica; não dá pra automatizar):

```powershell
Import-Certificate -FilePath .\caddy-root-ca.crt -CertStoreLocation Cert:\LocalMachine\Root
```

Repita em outros dispositivos que forem acessar os serviços via HTTPS — em Android, importe pelas configurações de segurança/credenciais; em iOS, instale o perfil e habilite confiança total em **Ajustes → Geral → Sobre → Confiança de certificado**.

## Backup

`caddy_data` (contém a chave privada da CA local) e `caddy_config` são volumes Docker; inclua-os no backup Restic junto com os demais volumes da stack — perder `caddy_data` significa gerar uma CA nova e reinstalar o certificado raiz em todos os dispositivos.

## Validação

- [x] `docker ps` mostra `caddy` `running`;
- [x] porta `443/tcp` liberada no UFW para a LAN;
- [x] `https://192.168.100.2:8443` (AdGuard), `:3000`, `:3001`, `:8080`, `:9443` abrem sem aviso de certificado depois de instalar a CA;
- [x] `http://192.168.100.2` (porta 80) continua respondendo em HTTP puro, sem regressão;
- [x] `https://*.home.arpa` funcionam sem alteração;
- [x] DNS (`53`) não foi afetado em nenhuma etapa;
- [x] regras "Docker monitor" do UFW atualizadas para as portas internas novas;
- [ ] monitores do Uptime Kuma (AdGuard Web, Portainer, HomeLab Web) reapontados para as portas internas;
- [ ] CA raiz instalada em todos os dispositivos que precisam acessar os serviços (hoje: só o notebook Windows principal).
