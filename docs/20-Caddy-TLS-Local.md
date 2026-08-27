# 20 — Caddy e TLS local

## Objetivo

Oferecer um caminho HTTPS confiável (`https://*.home.arpa`) para Portainer, AdGuard Home, Uptime Kuma, o site estático e o ntopng, usando um reverse proxy (Caddy) com CA interna emitida automaticamente por ele mesmo.

Esta é uma camada **aditiva**: o Caddy some por cima do que já está validado em [docs/12-UFW.md](12-UFW.md) e [docs/19-ntopng.md](19-ntopng.md). Nenhum bind, porta publicada ou regra UFW existente é alterado — os endereços diretos (`http://192.168.100.2`, `:3000`, `:3001`, `:8080`, `https://192.168.100.2:9443`) continuam funcionando exatamente como hoje.

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

O Caddy roda em `network_mode: host`, como o AdGuard, e escuta somente `:443` — a porta `:80` continua pertencendo ao AdGuard Home, então o Caddyfile desativa o redirecionamento automático HTTP→HTTPS (`auto_https disable_redirects`) para não colidir com ela.

## 2. Liberar a porta 443 no UFW

```bash
sudo ufw allow from 192.168.100.0/24 to any port 443 proto tcp comment 'Caddy TLS local LAN'
sudo ufw status verbose
```

Também aplicada por `scripts/configure-ufw.sh`, que já inclui essa regra.

## 3. Cadastrar os nomes locais no AdGuard Home

Em **Filters → DNS rewrites**, adicione, todos apontando para `192.168.100.2`:

- `portainer.home.arpa`
- `adguard.home.arpa`
- `kuma.home.arpa`
- `web.home.arpa`
- `ntop.home.arpa`

## 4. Testar o proxy

De um dispositivo na LAN (DNS resolvendo via AdGuard Home):

```powershell
curl.exe -sk -o NUL -w "%{http_code}`n" https://portainer.home.arpa
curl.exe -sk -o NUL -w "%{http_code}`n" https://adguard.home.arpa
curl.exe -sk -o NUL -w "%{http_code}`n" https://kuma.home.arpa
curl.exe -sk -o NUL -w "%{http_code}`n" https://web.home.arpa
curl.exe -sk -o NUL -w "%{http_code}`n" https://ntop.home.arpa
```

Vai aparecer aviso de certificado não confiável até a etapa 5.

## 5. Exportar e instalar a CA raiz

No servidor:

```bash
cd ~/homelab-infrastructure-server
./scripts/export-caddy-ca.sh
```

Copie `caddy-root-ca.crt` para o Windows (ex.: `scp leonardo@192.168.100.2:~/homelab-infrastructure-server/caddy-root-ca.crt .`) e instale como raiz confiável:

```powershell
Import-Certificate -FilePath .\caddy-root-ca.crt -CertStoreLocation Cert:\LocalMachine\Root
```

Requer PowerShell como administrador. Repita a instalação do mesmo arquivo em outros dispositivos que forem acessar os serviços via HTTPS — em Android, importe pelas configurações de segurança/credenciais; em iOS, instale o perfil e habilite confiança total em **Ajustes → Geral → Sobre → Confiança de certificado**.

## Backup

`caddy_data` (contém a chave privada da CA local) e `caddy_config` são volumes Docker; inclua-os no backup Restic junto com os demais volumes da stack, já que perder `caddy_data` significa gerar uma CA nova e reinstalar o certificado raiz em todos os dispositivos.

## Validação

- [ ] `docker ps` mostra `caddy` `running`;
- [ ] porta `443/tcp` liberada no UFW para a LAN;
- [ ] `https://portainer.home.arpa`, `https://adguard.home.arpa`, `https://kuma.home.arpa`, `https://web.home.arpa`, `https://ntop.home.arpa` abrem sem aviso de certificado após instalar a CA raiz;
- [ ] os endereços diretos (`http://192.168.100.2`, `:3000`, `:3001`, `:8080`, `https://192.168.100.2:9443`) continuam acessíveis sem alteração;
- [ ] resolução DNS (porta 53) não foi afetada.
