# 14 — Troubleshooting

## Diagnóstico rápido

```bash
./scripts/healthcheck.sh
```

## Docker não inicia

```bash
systemctl status docker --no-pager
journalctl -u docker -n 200 --no-pager
sudo dockerd --validate --config-file=/etc/docker/daemon.json
```

Se o `daemon.json` estiver inválido, corrija e reinicie:

```bash
sudo systemctl restart docker
```

## Container em reinicialização

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

- se o primeiro falhar, investigue o Unbound;
- se o primeiro funcionar e o segundo falhar, investigue AdGuard e porta 53;
- se ambos funcionarem, investigue DHCP/DNS do cliente.

## Unbound com erro

```bash
sudo unbound-checkconf
systemctl status unbound --no-pager
journalctl -u unbound -n 200 --no-pager
sudo ss -lntup | grep 5335
```

## Porta 53 ocupada

```bash
sudo ss -lntup | grep ':53 '
sudo lsof -i :53
```

Não mate serviços aleatoriamente. Identifique o processo e confirme o conflito.

## Cliente não recebe IP

1. Configure IP manual de emergência.
2. Confira se há apenas um DHCP ativo.
3. Veja os logs:

```bash
docker logs --tail 200 adguardhome
sudo ss -lunp | grep -E ':67 |:68 '
```

4. Se necessário, reative temporariamente o DHCP do modem.

## Sem acesso ao painel

```bash
docker ps
sudo ss -lntup | grep -E ':80 |:3000 |:3001 |:9443 '
sudo ufw status numbered
```

## Disco cheio

```bash
df -h /
sudo du -xhd1 /var | sort -h
docker system df
journalctl --disk-usage
```

Ações seguras:

```bash
sudo journalctl --vacuum-size=150M
docker image prune -f
sudo apt clean
```

## Rede perdida após Netplan

Use o console HDMI e teclado:

```bash
sudo cp /etc/netplan/backup-inicial.yaml /etc/netplan/50-cloud-init.yaml
sudo netplan generate
sudo netplan apply
```

Ajuste o nome do arquivo conforme o backup existente.

## Rollback completo da migração DHCP

- IP manual no notebook;
- DHCP do modem reativado;
- DHCP do AdGuard desativado;
- renovar lease dos clientes;
- investigar antes de tentar novamente.

## Informações para abrir uma issue

```bash
uname -a
cat /etc/os-release
ip -br address
ip route
docker version
docker compose version
docker ps -a
systemctl status unbound --no-pager
sudo ufw status verbose
df -h
```

Remova senhas, MACs, IP público e outros dados sensíveis antes de compartilhar logs.
