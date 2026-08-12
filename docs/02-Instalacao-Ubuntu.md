# 02 — Instalação do Ubuntu Server

## ISO utilizada

Use a imagem oficial **Ubuntu Server 24.04 LTS amd64**.

Arquivo de referência:

```text
ubuntu-24.04.x-live-server-amd64.iso
```

A implantação atual está em **Ubuntu Server 24.04.4 LTS**.

## Hardware da instalação

- Dell Wyse N03D / 3290;
- Intel Celeron N2807;
- 4 GB de RAM;
- SATA Flash Drive interno de 32 GB;
- armazenamento interno dedicado ao Ubuntu.

Durante uma reinstalação, mantenha qualquer mídia de backup **desconectada** até o sistema operacional estar instalado e o disco correto ser validado.

## Procedimento de instalação/reinstalação

1. Conecte vídeo, teclado, Ethernet e o pendrive do Ubuntu.
2. Desconecte a mídia de backup.
3. Inicie pelo pendrive USB.
4. Selecione `Try or Install Ubuntu Server`.
5. Use Ubuntu Server padrão, sem interface gráfica.
6. Mantenha DHCP temporariamente durante a instalação.
7. Deixe proxy em branco e mirror no padrão, salvo necessidade específica.
8. Selecione somente o **SATA Flash interno de 32 GB**.
9. Confirme a remoção das partições existentes somente depois de revisar o disco selecionado.
10. Hostname: `homelab`.
11. Usuário administrativo: `leonardo`.
12. Instale `OpenSSH server`.
13. Não instale snaps adicionais sem necessidade.
14. Finalize, remova o pendrive e reinicie.

## Primeiro acesso

No console:

```bash
ip -br address
hostnamectl
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL
```

Confirme que `/` está no armazenamento interno de aproximadamente 32 GB.

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

Depois:

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

O mesmo disco armazena Ubuntu, pacotes, imagens Docker e volumes ativos; por isso a política de logs permanece importante.

## Estado validado da implantação

- [x] Ubuntu Server 24.04.4 LTS inicializa pelo SATA Flash interno;
- [x] Windows removido;
- [x] hostname `homelab`;
- [x] SSH acessível;
- [x] timezone `America/Sao_Paulo`;
- [x] sistema atualizado durante a implantação;
- [x] armazenamento interno expandido para utilizar o LVM disponível;
- [x] mídia de backup mantida separada do disco de sistema.
