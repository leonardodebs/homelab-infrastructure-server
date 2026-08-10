# 02 — Instalação do Ubuntu Server

## ISO recomendada

Use a imagem oficial **Ubuntu Server 24.04 LTS amd64**.

Arquivo esperado:

```text
ubuntu-24.04.x-live-server-amd64.iso
```

## Hardware atual da instalação

O equipamento real está com:

- Dell Wyse N03D / 3290;
- Intel Celeron N2807;
- 4 GB de RAM;
- SATA Flash Drive interno de 32 GB;
- Windows 10 Pro atualmente instalado.

O Windows será removido e o SATA Flash de 32 GB será dedicado integralmente ao Ubuntu Server. O HD externo de 1 TB deve permanecer **desconectado durante a instalação** para eliminar qualquer risco de selecionar o disco errado.

## Instalação

1. Conecte vídeo, teclado, Ethernet e o pendrive do Ubuntu.
2. Deixe o HD externo de 1 TB desconectado.
3. Inicie pelo pendrive USB.
4. Selecione `Try or Install Ubuntu Server`.
5. Idioma: English ou Português.
6. Teclado: Portuguese (Brazil).
7. Tipo de instalação: Ubuntu Server padrão, sem interface gráfica.
8. Rede: mantenha DHCP nesta fase.
9. Proxy: deixe em branco.
10. Mirror: mantenha o padrão.
11. Armazenamento: selecione somente o **SATA Flash interno de 32 GB** e use o disco inteiro.
12. Confirme a remoção das partições existentes do Windows apenas depois de validar novamente o disco escolhido.
13. Hostname: `homeserver`.
14. Usuário sugerido: `leonardo`.
15. Marque `Install OpenSSH server`.
16. Não instale snaps adicionais.
17. Finalize, remova o pendrive e reinicie.

## Primeiro acesso

No console:

```bash
ip -br address
hostnamectl
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL
```

Confirme que o sistema raiz está no disco interno de aproximadamente 32 GB.

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

## Controle de logs para o armazenamento de 32 GB

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

O controle de logs continua importante mesmo com 32 GB, pois o mesmo disco armazenará Ubuntu, pacotes, imagens Docker e volumes ativos.

## Validação

```bash
df -h /
free -h
systemctl is-active ssh
journalctl --disk-usage
```

- [ ] Ubuntu inicializa sem pendrive;
- [ ] Windows removido e disco interno dedicado ao Ubuntu;
- [ ] SSH acessível;
- [ ] hostname `homeserver`;
- [ ] horário correto;
- [ ] sistema atualizado;
- [ ] espaço livre anotado;
- [ ] HD externo permaneceu fora do processo de instalação.
