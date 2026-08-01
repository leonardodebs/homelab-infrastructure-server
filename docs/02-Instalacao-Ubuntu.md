# 02 — Instalação do Ubuntu Server

## ISO recomendada

Use a imagem oficial **Ubuntu Server 24.04 LTS amd64**.

Arquivo esperado:

```text
ubuntu-24.04.x-live-server-amd64.iso
```

## Instalação

1. Conecte HDMI, teclado, Ethernet e pendrive.
2. Inicie pelo pendrive USB.
3. Selecione `Try or Install Ubuntu Server`.
4. Idioma: English ou Português.
5. Teclado: Portuguese (Brazil).
6. Tipo de instalação: Ubuntu Server padrão, sem interface gráfica.
7. Rede: mantenha DHCP nesta fase.
8. Proxy: deixe em branco.
9. Mirror: mantenha o padrão.
10. Armazenamento: use o SSD interno inteiro.
11. Hostname: `homeserver`.
12. Usuário sugerido: `leonardo`.
13. Marque `Install OpenSSH server`.
14. Não instale snaps adicionais.
15. Finalize, remova o pendrive e reinicie.

## Primeiro acesso

No console:

```bash
ip -br address
hostnamectl
```

No notebook:

```bash
ssh leonardo@IP_RECEBIDO
```

## Atualização inicial

```bash
sudo apt update
sudo apt full-upgrade -y
sudo apt autoremove --purge -y
sudo reboot
```

Após reiniciar:

```bash
cat /etc/os-release
uname -r
hostnamectl
ip -br address
```

## Pacotes básicos

```bash
sudo apt install -y \
  ca-certificates curl wget git nano vim htop btop \
  jq unzip tree dnsutils net-tools ufw smartmontools \
  unattended-upgrades
```

## Fuso horário

```bash
sudo timedatectl set-timezone America/Sao_Paulo
timedatectl
```

## Controle de logs para SSD pequeno

```bash
sudo mkdir -p /etc/systemd/journald.conf.d
sudo tee /etc/systemd/journald.conf.d/size.conf >/dev/null <<'EOF'
[Journal]
SystemMaxUse=200M
RuntimeMaxUse=100M
MaxRetentionSec=7day
EOF
sudo systemctl restart systemd-journald
```

## Validação

```bash
df -h /
free -h
systemctl is-active ssh
```

- [ ] Ubuntu inicializa sem pendrive;
- [ ] SSH acessível;
- [ ] hostname `homeserver`;
- [ ] horário correto;
- [ ] sistema atualizado;
- [ ] espaço livre anotado.
