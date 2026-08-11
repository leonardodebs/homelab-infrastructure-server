# 03 — Configuração inicial e IP estático

## 1. Identificar a interface Ethernet

```bash
ip -br link
ip -br address
```

Anote o nome da interface, por exemplo `enp1s0` ou `eno1`.

## 2. Descobrir o arquivo Netplan

```bash
ls -l /etc/netplan/
```

Faça backup:

```bash
sudo cp /etc/netplan/*.yaml /etc/netplan/backup-inicial.yaml
```

## 3. Configurar IP estático

Edite o YAML existente. Exemplo para a interface `enp1s0`:

```bash
sudo nano /etc/netplan/50-cloud-init.yaml
```

```yaml
network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      addresses:
        - 192.168.100.2/24
      routes:
        - to: default
          via: 192.168.100.1
      nameservers:
        addresses:
          - 1.1.1.1
          - 9.9.9.9
```

> Troque `enp1s0` pelo nome real. O DNS temporário será substituído pelo serviço local depois.

Valide e aplique com proteção contra perda de conexão:

```bash
sudo netplan generate
sudo netplan try
```

Se estiver conectado por SSH, confirme a configuração dentro do prazo mostrado. Depois:

```bash
sudo netplan apply
ip -br address
ip route
ping -c 3 192.168.100.1
ping -c 3 1.1.1.1
```

## 4. Confirmar hostname

```bash
sudo hostnamectl set-hostname homeserver
hostnamectl
```

Adicione ao `/etc/hosts`:

```bash
sudo nano /etc/hosts
```

Mantenha uma linha semelhante:

```text
127.0.1.1 homeserver
```

## 5. Segurança SSH básica

Crie uma chave no notebook, caso ainda não tenha:

```powershell
ssh-keygen -t ed25519
ssh-copy-id leonardo@192.168.100.2
```

No Windows sem `ssh-copy-id`, copie o conteúdo de `$HOME/.ssh/id_ed25519.pub` para:

```text
/home/leonardo/.ssh/authorized_keys
```

Somente depois de validar login por chave, edite:

```bash
sudo nano /etc/ssh/sshd_config.d/99-homelab.conf
```

```text
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
```

Valide antes de reiniciar:

```bash
sudo sshd -t
sudo systemctl restart ssh
```

Mantenha a sessão atual aberta e teste uma nova conexão.

## 6. Atualizações automáticas de segurança

```bash
sudo dpkg-reconfigure --priority=low unattended-upgrades
systemctl status unattended-upgrades --no-pager
```

## 7. Diretórios do projeto

```bash
sudo mkdir -p /opt/homelab/{compose,data,backups,scripts}
sudo chown -R "$USER":"$USER" /opt/homelab
```

## 8. Validação

```bash
hostname -I
ip route
resolvectl status
ss -lntup
```

- [ ] IP `192.168.100.2` persistente;
- [ ] gateway `192.168.100.1`;
- [ ] SSH por chave funcionando;
- [ ] login root remoto bloqueado;
- [ ] diretórios em `/opt/homelab` criados.
