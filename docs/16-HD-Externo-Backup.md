# 16 — Mídia USB dedicada ao backup

Este capítulo documenta a mídia removível usada para proteger o HomeLab com Restic.

## Mídia atual validada

A implantação atual usa um **pendrive USB de 128 GB nominais / 117,19 GiB utilizáveis**.

Por segurança e privacidade, serial, MAC, UUID real e outros identificadores únicos não são publicados neste repositório.

Antes do uso, a capacidade foi validada com F3:

```bash
sudo f3probe --destructive --time-ops /dev/sdX
```

Resultado observado na mídia atual:

```text
Good news: The device is the real thing
Usable size:    117.19 GB
Announced size: 117.19 GB
Module:         128.00 GB
```

> `f3probe --destructive` apaga a mídia. Use apenas depois de confirmar o dispositivo correto.

O HD externo de maior capacidade permanece como opção futura, não como requisito da implantação atual.

## Arquitetura atual

```text
SATA Flash interno 32 GB — produção
├── Ubuntu Server
├── Docker e imagens
├── AdGuard Home
├── Portainer
├── Uptime Kuma
├── Beszel
├── Diun
├── HomeLab Web
└── Unbound

Mídia USB 128 GB — backup
└── /srv/backup
    ├── restic
    ├── restore-tests
    └── status
```

## Identificar o dispositivo

Nunca dependa apenas de `/dev/sdb`, pois a letra pode mudar.

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS,MODEL,TRAN,RM
```

Confirme:

- transporte USB;
- capacidade esperada;
- ausência de mountpoints antes de formatar;
- que o dispositivo não contém `/`, `/boot` ou `/boot/efi`.

## Preparação

```bash
cd ~/homelab-infrastructure-server
sudo bash scripts/prepare-backup-disk.sh /dev/sdX
```

O script:

1. recusa o disco do sistema;
2. recusa partições montadas;
3. exige confirmação textual explícita;
4. cria GPT;
5. cria uma partição ext4;
6. aplica label `HOMELAB_BACKUP`;
7. adiciona montagem por UUID em `/etc/fstab`;
8. monta em `/srv/backup`;
9. cria os diretórios da stack de backup.

Estado esperado:

```text
FSTYPE : ext4
LABEL  : HOMELAB_BACKUP
MOUNT  : /srv/backup
SIZE   : ~115G
```

A entrada no `fstab` segue o padrão:

```fstab
UUID=<UUID_REAL_LOCAL> /srv/backup ext4 defaults,nofail,x-systemd.automount,x-systemd.device-timeout=10s 0 2
```

Valide:

```bash
findmnt /srv/backup
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS,TRAN
df -h /srv/backup
sudo mount -a
sudo ls -lah /srv/backup
```

Diretórios:

```text
/srv/backup/restic
/srv/backup/restore-tests
/srv/backup/status
```

## Stack de backup

A stack usa:

- ext4;
- Restic com criptografia, deduplicação e snapshots incrementais;
- systemd timers;
- `flock` para impedir operações simultâneas;
- retenção e prune;
- `restic check`;
- restore test mensal;
- SMART somente quando suportado pela mídia.

Pendrives normalmente não oferecem SMART útil. A ausência de SMART não é tratada como falha do backup.

## Dados protegidos

Incluídos:

- repositório e Compose;
- `/etc/fstab`;
- Netplan;
- Unbound;
- Docker daemon config;
- UFW;
- units do systemd;
- MOTD do HomeLab;
- configuração Restic sem senha;
- volumes do Portainer;
- AdGuard Home;
- Uptime Kuma;
- Beszel Hub e Agent;
- Diun.

O portal HomeLab é estático e está no próprio repositório Git.

Excluídos:

- `/etc/homelab-backup/restic-password`;
- `/srv/backup` como origem;
- imagens e layers recriáveis do Docker;
- caches e logs temporários.

## Política

| Rotina | Horário | Ação |
|---|---:|---|
| Backup | diariamente às 03:15 | snapshot criptografado e incremental |
| Manutenção | domingo às 04:30 | retenção, prune, check parcial e tentativa de SMART |
| Restore test | dia 1 às 05:30 | restauração do snapshot mais recente em diretório isolado |

Retenção:

- 7 diários;
- 8 semanais;
- 12 mensais;
- 2 anuais.

## Instalação do Restic e timers

```bash
sudo bash scripts/install-backup-stack.sh
```

A senha Restic deve ter pelo menos 16 caracteres e ser guardada fora do servidor.

Valide:

```bash
restic version
systemctl list-timers 'homelab-*' --no-pager
sudo systemctl status homelab-backup.timer --no-pager
sudo systemctl status homelab-backup-maintenance.timer --no-pager
sudo systemctl status homelab-restore-test.timer --no-pager
```

## Validação real da implantação — 2026-08-11

O primeiro ciclo completo de backup, integridade e restauração foi executado com sucesso.

### Snapshot inicial

```text
Snapshot: a79a4c33
Host:     homelab
Tag:      homelab
Arquivos: 279
Tamanho lógico: 5.878 MiB
```

O Restic reportou 604 objetos de filesystem no snapshot, incluindo diretórios.

### Integridade

```bash
sudo bash -c 'source /etc/homelab-backup/restic.env; restic check'
```

Resultado:

```text
no errors were found
```

### Restore test

O snapshot foi restaurado em diretório isolado dentro de:

```text
/srv/backup/restore-tests/
```

O Restic informou:

```text
Summary: Restored 604 files/dirs (5.878 MiB)
```

O script contabilizou 279 arquivos regulares e criou `RESTORE_TEST_OK.txt` com:

```text
status=success
files_restored=279
snapshot=latest
```

Isso comprova que o snapshot pode ser lido e restaurado sem sobrescrever produção.

## Operação manual

Backup:

```bash
sudo systemctl start homelab-backup.service
sudo journalctl -u homelab-backup.service -f
```

Restore test:

```bash
sudo systemctl start homelab-restore-test.service
sudo journalctl -u homelab-restore-test.service --no-pager -n 100
```

## Remoção segura da mídia

Antes de remover fisicamente:

```bash
sudo systemctl stop homelab-backup.timer
sudo systemctl stop homelab-backup-maintenance.timer
sudo systemctl stop homelab-restore-test.timer

systemctl is-active homelab-backup.service
systemctl is-active homelab-backup-maintenance.service
systemctl is-active homelab-restore-test.service

sudo sync
sudo umount /srv/backup
```

Depois de reconectar, confirme `findmnt /srv/backup` antes de esperar novos backups.

## Limitações

A mídia atual atende ao laboratório, mas não implementa 3-2-1 sozinha. Ela não protege contra:

- roubo;
- incêndio;
- surto elétrico que atinja servidor e mídia;
- falha física da própria mídia;
- perda da senha Restic.

Como evolução futura, use uma segunda cópia criptografada, rotação offline ou mídia de maior capacidade.
