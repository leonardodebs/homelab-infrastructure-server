# 03 — Configuração inicial e IP estático

## Estado atual

O servidor opera com:

```text
Hostname : homelab
IP       : 192.168.100.2/24
Gateway  : 192.168.100.1
Rede     : 192.168.100.0/24
Ethernet : adaptador TP-Link UE300 USB 3.0
Timezone : America/Sao_Paulo
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

## 5. Hardening SSH — concluído

A autenticação por chave ED25519 foi validada a partir do notebook Windows antes da desativação de senha.

A chave pública fica em:

```text
/home/leonardo/.ssh/authorized_keys
```

Permissões esperadas:

```text
~/.ssh                  0700
~/.ssh/authorized_keys  0600
```

A política final é aplicada por um arquivo carregado antes do `50-cloud-init.conf` para evitar que `PasswordAuthentication yes` do cloud-init prevaleça:

```text
/etc/ssh/sshd_config.d/00-homelab.conf
```

Conteúdo:

```text
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
```

Validação:

```bash
sudo sshd -t
sudo systemctl reload ssh
sudo sshd -T | grep -Ei 'passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|permitrootlogin'
```

Estado efetivo esperado:

```text
permitrootlogin no
pubkeyauthentication yes
passwordauthentication no
kbdinteractiveauthentication no
```

Teste positivo a partir do cliente:

```powershell
ssh leonardo@192.168.100.2
```

Teste negativo, desabilitando chave no cliente:

```powershell
ssh -o PubkeyAuthentication=no -o KbdInteractiveAuthentication=no leonardo@192.168.100.2
```

Resultado validado:

```text
Permission denied (publickey).
```

A senha do usuário Linux continua válida localmente e para `sudo`; apenas a autenticação remota por senha foi desativada.

## 6. Atualizações automáticas de segurança — auditadas

Os seguintes componentes foram validados como ativos:

```bash
systemctl status unattended-upgrades --no-pager
systemctl status apt-daily.timer --no-pager
systemctl status apt-daily-upgrade.timer --no-pager
```

Configuração periódica efetiva:

```text
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
```

Origens automáticas permitidas incluem o release base, `noble-security` e, quando disponíveis/ativos, os pockets ESM de segurança. `noble-updates`, `proposed` e `backports` não foram habilitados para upgrade automático.

O log comprovou execução real com instalação bem-sucedida de atualizações e execução posterior sem pacotes pendentes.

O reboot automático não está habilitado. A política operacional é instalar atualizações automáticas elegíveis e executar reinicializações manualmente quando necessárias.

Comandos de auditoria:

```bash
sudo apt-config dump | grep -Ei \
'Periodic::Update-Package-Lists|Periodic::Unattended-Upgrade|Unattended-Upgrade::Automatic-Reboot'

sudo tail -n 50 /var/log/unattended-upgrades/unattended-upgrades.log
```

## 7. Horário e sincronização

O host foi padronizado para:

```text
Timezone  : America/Sao_Paulo
Offset    : -03:00
RTC       : UTC
LocalRTC  : no
NTP       : systemd-timesyncd sincronizado
```

Validação rápida:

```bash
date -Is
timedatectl
readlink -f /etc/localtime
cat /etc/timezone
timedatectl timesync-status
```

Tanto `/etc/localtime` quanto `/etc/timezone` devem apontar/indicar `America/Sao_Paulo`.

A auditoria detalhada de timers, cron, containers e schedulers está em [17 — Horário e agendamentos](17-Horario-Agendamentos.md).

## 8. Diretórios do projeto

O repositório operacional fica em:

```text
/home/leonardo/homelab-infrastructure-server
```

Diretórios auxiliares em `/opt/homelab` podem existir, mas a stack Compose atual é executada diretamente a partir do clone do GitHub.

## 9. Validação

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
- [x] autenticação SSH por chave validada;
- [x] autenticação SSH por senha desativada;
- [x] login root remoto desativado;
- [x] keyboard-interactive desativado;
- [x] política `unattended-upgrades` auditada;
- [x] reboot automático não supervisionado desativado;
- [x] timezone, RTC e NTP validados.
