# 05 — Portainer

O Portainer será instalado pela stack em `compose/compose.yaml`.

## Preparação

```bash
cd ~/homelab-infrastructure-server
cp compose/.env.example compose/.env
nano compose/.env
```

Confirme:

```text
SERVER_IP=192.168.100.2
```

## Subir somente o Portainer

```bash
docker compose --env-file compose/.env -f compose/compose.yaml up -d portainer
```

## Acesso

Abra no navegador:

```text
https://192.168.100.2:9443
```

Desde o [capítulo 20](20-Caddy-TLS-Local.md), quem responde nessa porta é o Caddy, com certificado emitido pela CA interna (confiável, sem aviso de segurança, desde que a CA esteja instalada no dispositivo). O Portainer em si só é alcançável internamente em `192.168.100.2:9444` (porta publicada pelo compose), onde continua servindo seu próprio HTTPS autoassinado — é para esse endereço interno que o Caddy encaminha, ignorando a validade do certificado apenas nesse trecho interno (`tls_insecure_skip_verify`).

## Primeira configuração

1. Crie o usuário administrador.
2. Use uma senha longa e exclusiva.
3. Selecione o ambiente Docker local.
4. Não habilite exposição pública.

## Validação

```bash
docker ps --filter name=portainer
docker logs --tail 50 portainer
curl -I https://192.168.100.2:9443
curl -kI https://192.168.100.2:9444
```

## Backup

O volume `portainer_data` é incluído pelo script de backup do projeto.

## Atualização manual

```bash
cd ~/homelab-infrastructure-server
docker compose --env-file compose/.env -f compose/compose.yaml pull portainer
docker compose --env-file compose/.env -f compose/compose.yaml up -d portainer
```

## Recuperação

```bash
docker compose --env-file compose/.env -f compose/compose.yaml restart portainer
docker logs -f portainer
```
