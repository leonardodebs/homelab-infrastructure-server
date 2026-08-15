# 09A — Uptime Kuma

O Uptime Kuma monitora disponibilidade e tempo de resposta dos componentes do HomeLab.

## Acesso

```text
http://192.168.100.2:3001
```

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
   - URL: `http://192.168.100.2`.

5. **Portainer**
   - tipo: HTTPS;
   - URL: `https://192.168.100.2:9443`;
   - certificado autoassinado ignorado somente neste monitor.

6. **Beszel Web**
   - tipo: HTTP;
   - URL: `http://192.168.100.2:8090`.

7. **HomeLab Web**
   - tipo: HTTP;
   - URL: `http://192.168.100.2:8080`.

Todos os monitores foram validados após o ajuste do UFW para permitir que a rede Docker `homelab_default` alcance as portas monitoradas no IP do host.

## Particularidade Docker -> host

O Kuma roda dentro da rede Docker. Quando acessa `192.168.100.2`, o tráfego não chega com origem na LAN `192.168.100.0/24`, e sim com origem na subnet da rede `homelab_default`.

Por isso `docs/11-UFW.md` e `scripts/configure-ufw.sh` incluem regras específicas para os checks internos.

Nunca presuma uma subnet Docker fixa; valide:

```bash
docker network inspect homelab_default \
  --format '{{range .IPAM.Config}}Subnet={{.Subnet}} Gateway={{.Gateway}}{{end}}'
```

## Validação

```bash
docker ps --filter name=uptime-kuma
docker logs --tail 100 uptime-kuma
curl -I http://192.168.100.2:3001
```

Teste direto de dentro do container quando houver timeout inesperado:

```bash
docker exec uptime-kuma node -e \
"fetch('http://192.168.100.2:8080').then(r=>console.log(r.status)).catch(console.error)"
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
- [x] volume incluído no Restic.
