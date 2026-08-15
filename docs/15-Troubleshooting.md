# 15 — Troubleshooting

## Diagnóstico rápido

```bash
cd ~/homelab-infrastructure-server
./scripts/healthcheck.sh
```

## Docker não inicia

```bash
systemctl status docker --no-pager
journalctl -u docker -n 200 --no-pager
sudo dockerd --validate --config-file=/etc/docker/daemon.json
```

Se o `daemon.json` estiver inválido, corrija antes de reiniciar:

```bash
sudo systemctl restart docker
```

## Container em reinicialização ou unhealthy

```bash
docker ps -a
docker inspect NOME_DO_CONTAINER
docker logs --tail 200 NOME_DO_CONTAINER
```

## DNS não resolve

Teste por camadas:

```bash
dig @127.0.0.1 -p 5335 ubuntu.com
dig @192.168.100.2 ubuntu.com
```

Interpretação:

- primeiro falha -> investigar Unbound;
- primeiro funciona e segundo falha -> investigar AdGuard/porta 53;
- ambos funcionam -> investigar DHCP, DNS ou DoH/Private DNS no cliente.

## Unbound com erro

```bash
sudo unbound-checkconf
systemctl status unbound --no-pager
journalctl -u unbound -n 200 --no-pager
sudo ss -lntup | grep 5335
```

O Unbound deve permanecer em `127.0.0.1:5335`.

## Porta 53 ocupada

```bash
sudo ss -lntup | grep ':53 '
sudo lsof -i :53
```

Identifique o processo antes de alterar qualquer serviço.

## Cliente não recebe IP

```bash
docker logs --tail 200 adguardhome
sudo ss -lunp | grep -E ':(67|68)\b'
ip -br address
```

Confirme:

- somente um servidor DHCPv4 ativo;
- AdGuard em UDP/67;
- Huawei com DHCP desativado;
- UFW permitindo DHCP pela interface LAN;
- pool DHCP com endereços disponíveis.

Em emergência, use IP manual temporário no notebook e reative DHCP no Huawei somente como rollback.

## Login do AdGuard falha

Erros conhecidos:

```text
403 invalid username or password
429 auth: blocked for ...
```

Configuração atual:

```yaml
auth_attempts: 5
block_auth_min: 3
```

Confira logs:

```bash
docker logs --tail 100 adguardhome | grep -Ei 'auth|login|403|429|blocked'
```

Se aparecer 429, aguarde o período de bloqueio antes de tentar novamente.

Se a senha precisar ser redefinida, siga o procedimento de `docs/06-AdGuardHome.md`. Não publique senha ou hash bcrypt.

## Interfaces web inacessíveis

```bash
docker ps
sudo ss -lntup | grep -E '(:80|:3001|:8080|:8090|:9443)\b'
sudo ufw status numbered
```

URLs atuais:

```text
AdGuard      http://192.168.100.2
Uptime Kuma  http://192.168.100.2:3001
HomeLab Web  http://192.168.100.2:8080
Beszel       http://192.168.100.2:8090
Portainer    https://192.168.100.2:9443
```

## Uptime Kuma mostra timeout mas o serviço está online

Valide a subnet Docker:

```bash
docker network inspect homelab_default \
  --format '{{range .IPAM.Config}}Subnet={{.Subnet}} Gateway={{.Gateway}}{{end}}'
```

O Kuma acessa o IP do host a partir da rede Docker. Confira as regras Docker -> host descritas em `docs/12-UFW.md`.

Teste de dentro do Kuma:

```bash
docker exec uptime-kuma node -e \
"fetch('http://192.168.100.2:8080').then(r=>console.log(r.status)).catch(console.error)"
```

## Beszel Agent offline

```bash
docker ps --filter name=beszel-agent
docker logs --tail 200 beszel-agent
docker inspect --format '{{.State.Health.Status}}' beszel-agent
```

Verifique `HUB_URL`, `BESZEL_KEY` e `BESZEL_TOKEN` somente localmente no `.env`. Não compartilhe esses valores.

A arquitetura não usa a porta 45876.

## Backup falha

```bash
findmnt /srv/backup
df -h /srv/backup
sudo cat /srv/backup/status/last-success.txt
sudo journalctl -u homelab-backup.service --no-pager -n 200
```

Se `/srv/backup` não estiver montado, o script cancela o backup deliberadamente para não gravar no SATA Flash interno.

Verifique também:

```bash
sudo dmesg -T | grep -Ei 'usb|uas|reset|I/O error|buffer I/O|sd[a-z]'
```

## Restic com erro

```bash
sudo bash -c 'source /etc/homelab-backup/restic.env; restic snapshots'
sudo bash -c 'source /etc/homelab-backup/restic.env; restic check'
```

Nunca apague manualmente arquivos dentro de `/srv/backup/restic`.

## Restore test falha

```bash
sudo journalctl -u homelab-restore-test.service --no-pager -n 200
sudo find /srv/backup/restore-tests -maxdepth 2 -name RESTORE_TEST_OK.txt -print
```

O teste deve restaurar em diretório isolado; não escreva automaticamente sobre produção.

## Disco interno cheio

```bash
df -h /
sudo du -xhd1 /var | sort -h
docker system df
journalctl --disk-usage
```

Ações conservadoras:

```bash
sudo journalctl --vacuum-size=150M
docker image prune -f
sudo apt clean
```

Não use `docker system prune --volumes`.

## Rede perdida após Netplan

Use console HDMI/teclado e restaure o backup real do YAML:

```bash
ls -lah /etc/netplan
sudo netplan generate
sudo netplan try
```

Não sobrescreva arquivos antes de identificar qual backup é válido.

## Informações para diagnóstico/issue

```bash
uname -a
cat /etc/os-release
hostnamectl
ip -br address
ip route
docker version
docker compose version
docker ps -a
systemctl status unbound --no-pager
sudo ufw status verbose
df -h /
df -h /srv/backup
systemctl list-timers 'homelab-*' --no-pager
```

Antes de compartilhar logs, remova:

- senhas;
- hashes bcrypt;
- tokens e chaves Beszel;
- MAC addresses e seriais;
- IP público;
- outras credenciais ou identificadores únicos.
