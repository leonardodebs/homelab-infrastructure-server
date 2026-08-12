# 03 — Configuração inicial e IP estático

## Estado atual

O servidor opera com:

```text
Hostname : homelab
IP       : 192.168.100.2/24
Gateway  : 192.168.100.1
Rede     : 192.168.100.0/24
Ethernet : adaptador TP-Link UE300 USB 3.0
```

O nome exato da interface deve ser detectado no próprio host em vez de ser publicado como identificador fixo no repositório.

## 1. Identificar a interface Ethernet

```bash
ip -br link
ip -br address
```

Também é possível localizar a interface que possui o IP do servidor:

```bash
ip -o -4 addr show | awk '$4 ~ /^192\.168\.100\.2\// {print $2}'
```

## 2. Descobrir o arquivo Netplan

```bash
ls -l /etc/netplan/
```

Antes de editar:

```bash
sudo cp /etc/netplan/50-cloud-init.yaml \
  /etc/netplan/50-cloud-init.yaml.backup
```

Ajuste o nome se o arquivo real for diferente.

## 3. Configurar IP estático

Exemplo genérico:

```yaml
network:
  version: 2
  ethernets:
    INTERFACE_REAL:
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

Os DNS públicos acima são apenas temporários para a fase inicial. Depois da implantação do AdGuard/Unbound, a resolução do host deve seguir a configuração final definida no servidor.

Valide com proteção contra perda de conexão:

```bash
sudo netplan generate
sudo netplan try
```

Depois:

```bash
sudo netplan apply
ip -br address
ip route
ping -c 3 192.168.100.1
ping -c 3 1.1.1.1
```

## 4. Hostname

```bash
sudo hostnamectl set-hostname homelab
hostnamectl
```

Em `/etc/hosts`, mantenha a referência local coerente:

```text
127.0.1.1 homelab
```

## 5. Hardening SSH — próxima etapa

O SSH funciona atualmente na LAN. O próximo hardening recomendado é migrar para autenticação por chave.

No notebook Windows:

```powershell
ssh-keygen -t ed25519
```

Copie a chave pública para:

```text
/home/leonardo/.ssh/authorized_keys
```

Somente depois de validar uma segunda sessão usando a chave, crie:

```bash
sudo nano /etc/ssh/sshd_config.d/99-homelab.conf
```

```text
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
```

Valide antes de recarregar:

```bash
sudo sshd -t
sudo systemctl reload ssh
```

Mantenha a sessão atual aberta até comprovar o novo login.

## 6. Atualizações automáticas de segurança

Audite:

```bash
systemctl status unattended-upgrades --no-pager
systemctl status apt-daily.timer --no-pager
systemctl status apt-daily-upgrade.timer --no-pager
```

A política desejada é aplicar atualizações de segurança automaticamente, sem reboot automático não supervisionado.

## 7. Diretórios do projeto

O repositório operacional fica em:

```text
/home/leonardo/homelab-infrastructure-server
```

Diretórios auxiliares em `/opt/homelab` podem existir, mas a stack Compose atual é executada diretamente a partir do clone do GitHub.

## 8. Validação

```bash
hostnamectl --static
hostname -I
ip route
resolvectl status
ss -lntup
```

Estado atual:

- [x] hostname `homelab`;
- [x] IP `192.168.100.2` persistente;
- [x] gateway `192.168.100.1`;
- [x] SSH funcional na LAN;
- [ ] autenticação SSH por chave validada;
- [ ] autenticação SSH por senha desativada após validação da chave;
- [ ] política `unattended-upgrades` auditada como etapa final de hardening.
