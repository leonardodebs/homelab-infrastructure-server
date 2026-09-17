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
dig @192.168.15.2 ubuntu.com
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

Desde o [capítulo 20](20-Caddy-TLS-Local.md), o Caddy termina TLS nas portas públicas e encaminha para as portas internas reais. Verifique as duas camadas:

```bash
docker ps
sudo ss -lntup | grep -E '(:80|:443|:3000|:3001|:8080|:8443|:9443|:9899|:8280|:3300|:3101|:8180|:9444)\b'
sudo ufw status numbered
docker logs --tail 50 caddy
```

URLs públicas (via Caddy, HTTPS confiável com a CA instalada):

```text
AdGuard      http://192.168.15.2  (porta 80, sem TLS)  |  https://192.168.15.2:8443
Uptime Kuma  https://192.168.15.2:3001
HomeLab Web  https://192.168.15.2:8080
Portainer    https://192.168.15.2:9443
ntopng       https://192.168.15.2:3000
Backrest     https://192.168.15.2:9899
```

Portas internas reais (o que o Caddy encaminha): `8280` (AdGuard), `3300` (ntopng), `3101` (Kuma), `8180` (HomeLab Web), `9444` (Portainer), `127.0.0.1:9898` (Backrest).

### Caddy não sobe ou não serve um site

```bash
docker logs --tail 80 caddy
docker exec caddy caddy validate --config /etc/caddy/Caddyfile
```

Depois de um `git pull` que muda o `Caddyfile`, **sempre** rode `docker restart caddy` — `caddy reload` sozinho não pega o conteúdo novo por causa do bind mount de arquivo único.

Se o navegador mostra "não confiável", a CA do Caddy não está instalada nesse dispositivo — ver [docs/20-Caddy-TLS-Local.md](20-Caddy-TLS-Local.md).

## Uptime Kuma mostra timeout mas o serviço está online

Valide a subnet Docker:

```bash
docker network inspect homelab_default \
  --format '{{range .IPAM.Config}}Subnet={{.Subnet}} Gateway={{.Gateway}}{{end}}'
```

O Kuma acessa o IP do host a partir da rede Docker. Confira as regras Docker -> host descritas em `docs/12-UFW.md`.

Teste de dentro do Kuma (use a porta interna real, não a pública que agora é TLS):

```bash
docker exec uptime-kuma node -e \
"fetch('http://192.168.15.2:8180').then(r=>console.log(r.status)).catch(console.error)"
```

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

## Grafana/ntopng mostra tráfego absurdo ("top talkers")

Antes de investigar como incidente de segurança, compare com o contador real da interface:

```bash
ip -s link show lan0
R1=$(cat /sys/class/net/lan0/statistics/rx_bytes); T1=$(cat /sys/class/net/lan0/statistics/tx_bytes)
sleep 5
R2=$(cat /sys/class/net/lan0/statistics/rx_bytes); T2=$(cat /sys/class/net/lan0/statistics/tx_bytes)
echo "RX: $(( (R2-R1)/5 )) B/s   TX: $(( (T2-T1)/5 )) B/s"
```

Se o painel mostra ordens de magnitude a mais que o total acumulado desde o boot (ou que a taxa medida ao vivo), é classificação errada no ntopng, não tráfego real. Suspeite primeiro do `-m=` (local-networks) em `/etc/ntopng/ntopng.conf` — se estiver com uma faixa de IP diferente da LAN atual, todo tráfego local passa a ser contado como "Internet". Caso real e documentado: [docs/19-ntopng.md](19-ntopng.md#incidente-top-talkers-absurdos-no-grafana-17092026).

Também vale conferir `docker stats --no-stream` (rede por container) e `ss -tn state established` para descartar qualquer processo real fazendo upload fora do padrão.

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
- MAC addresses e seriais;
- IP público;
- outras credenciais ou identificadores únicos.
