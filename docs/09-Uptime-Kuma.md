# 09 — Uptime Kuma

O Uptime Kuma monitora disponibilidade e tempo de resposta dos componentes do HomeLab.

## Acesso

```text
https://192.168.100.2:3001
```

Desde o [capítulo 20](20-Caddy-TLS-Local.md), essa porta é servida pelo Caddy com certificado confiável. O container em si migrou para a porta interna `192.168.100.2:3101` (publicada pelo compose), usada pelo Caddy e pelos checks internos do próprio Kuma.

Instalação/recriação:

```bash
cd ~/homelab-infrastructure-server
docker compose --env-file compose/.env -f compose/compose.yaml up -d uptime-kuma
```

## Monitores atuais validados

A implantação opera com sete monitores:

1. **Gateway Huawei**
   - tipo: Ping;
   - host: `192.168.100.1`.

2. **Internet**
   - tipo: Ping;
   - host: `1.1.1.1`.

3. **AdGuard DNS**
   - tipo: DNS;
   - resolver: `192.168.100.2`;
   - porta: `53`;
   - consulta A de teste: `ubuntu.com`.

4. **AdGuard Web**
   - tipo: HTTP;
   - URL: `http://192.168.100.2:8280` (porta interna real; a porta pública `80` agora é TLS via Caddy).

5. **Portainer**
   - tipo: HTTPS;
   - URL: `https://192.168.100.2:9444` (porta interna real; a porta pública `9443` agora é TLS via Caddy);
   - certificado autoassinado ignorado somente neste monitor.

6. **HomeLab Web**
   - tipo: HTTP;
   - URL: `http://192.168.100.2:8180` (porta interna real; a porta pública `8080` agora é TLS via Caddy).

Todos os monitores foram validados após o ajuste do UFW para permitir que a rede Docker `homelab_default` alcance as portas monitoradas no IP do host.

> Desde o [capítulo 20](20-Caddy-TLS-Local.md), os monitores 4, 5 e 6 apontam para as portas internas dos serviços, não mais para as portas públicas — as públicas (`80`, `9443`, `8080`) passaram a ser terminadas em TLS pelo Caddy e não respondem mais como antes a um simples GET HTTP/HTTPS direto sem SNI/porta corretos.

## Particularidade Docker -> host

O Kuma roda dentro da rede Docker. Quando acessa `192.168.100.2`, o tráfego não chega com origem na LAN `192.168.100.0/24`, e sim com origem na subnet da rede `homelab_default`.

Por isso `docs/12-UFW.md` e `scripts/configure-ufw.sh` incluem regras específicas para os checks internos.

Nunca presuma uma subnet Docker fixa; valide:

```bash
docker network inspect homelab_default \
  --format '{{range .IPAM.Config}}Subnet={{.Subnet}} Gateway={{.Gateway}}{{end}}'
```

## Validação

```bash
docker ps --filter name=uptime-kuma
docker logs --tail 100 uptime-kuma
curl -I https://192.168.100.2:3001
curl -I http://192.168.100.2:3101
```

Teste direto de dentro do container quando houver timeout inesperado:

```bash
docker exec uptime-kuma node -e \
"fetch('http://192.168.100.2:8180').then(r=>console.log(r.status)).catch(console.error)"
```

## Backup

O volume persistente é:

```text
homelab_uptime_kuma_data
```

Ele é incluído pelo backup Restic do projeto. Durante o snapshot, o container é interrompido brevemente para manter consistência e iniciado novamente automaticamente.

## Segurança

- porta 3001 somente na LAN;
- nenhum port forwarding no Huawei;
- senha administrativa exclusiva;
- não expor página de status publicamente sem uma decisão explícita de arquitetura;
- revisar os monitores depois de qualquer mudança de portas, firewall ou rede Docker.

## Estado atual

- [x] sete monitores configurados;
- [x] checks DNS e HTTP funcionando;
- [x] Portainer monitorado com certificado autoassinado;
- [x] regras Docker -> host do UFW validadas;
- [x] volume incluído no Restic;
- [ ] monitores 4 (AdGuard Web), 5 (Portainer) e 6 (HomeLab Web) reapontados para as portas internas novas (8280/9444/8180) depois da migração do capítulo 20.
