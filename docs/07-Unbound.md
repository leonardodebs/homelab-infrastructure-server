# 07 — Unbound

O Unbound será instalado como serviço nativo do Ubuntu e escutará apenas em `127.0.0.1:5335`.

## Instalação

```bash
sudo apt update
sudo apt install -y unbound unbound-anchor dns-root-data
```

## Copiar a configuração do projeto

A partir do repositório clonado:

```bash
sudo cp config/unbound/homelab.conf /etc/unbound/unbound.conf.d/homelab.conf
```

## Atualizar root hints

```bash
sudo mkdir -p /var/lib/unbound
sudo curl -fsSL https://www.internic.net/domain/named.cache \
  -o /var/lib/unbound/root.hints
sudo chown unbound:unbound /var/lib/unbound/root.hints
```

O pacote normalmente mantém a âncora DNSSEC automaticamente. Confira:

```bash
sudo ls -l /var/lib/unbound/root.key
```

## Validar configuração

```bash
sudo unbound-checkconf
```

Se não houver erro:

```bash
sudo systemctl enable --now unbound
sudo systemctl restart unbound
```

## Testes

```bash
systemctl status unbound --no-pager
sudo ss -lntup | grep 5335
```

```bash
dig @127.0.0.1 -p 5335 google.com
dig @127.0.0.1 -p 5335 cloudflare.com +dnssec
dig @127.0.0.1 -p 5335 dnssec-failed.org
```

Com DNSSEC funcionando, `dnssec-failed.org` deve falhar com `SERVFAIL`.

## Integração com AdGuard Home

No painel do AdGuard Home, em upstream DNS servers, informe:

```text
127.0.0.1:5335
```

Como o AdGuard usa `network_mode: host`, o endereço de loopback do container é o mesmo do host.

## Cache

Repita uma consulta e compare os tempos:

```bash
dig @127.0.0.1 -p 5335 ubuntu.com | grep 'Query time'
dig @127.0.0.1 -p 5335 ubuntu.com | grep 'Query time'
```

A segunda consulta tende a ser mais rápida por causa do cache.

## Logs

```bash
journalctl -u unbound --since today
```

## Atualização periódica dos root hints

Crie um timer mensal ou atualize durante a manutenção:

```bash
sudo curl -fsSL https://www.internic.net/domain/named.cache \
  -o /var/lib/unbound/root.hints
sudo chown unbound:unbound /var/lib/unbound/root.hints
sudo unbound-checkconf
sudo systemctl restart unbound
```

## Recuperação

```bash
sudo unbound-checkconf
sudo systemctl restart unbound
journalctl -u unbound -n 100 --no-pager
```

- [ ] Unbound ativo;
- [ ] porta `5335` somente em loopback;
- [ ] consulta normal funciona;
- [ ] validação DNSSEC funciona;
- [ ] AdGuard usa apenas o Unbound como upstream.
