# 16 — Mídia USB dedicada ao backup

Este capítulo documenta a mídia removível usada para proteger o HomeLab com Restic.

## Mídia atual validada

A implantação atual usa um **pendrive USB de 128 GB nominais / 117,19 GiB utilizáveis**, identificado pelo Linux como:

```text
/dev/sdb
Vendor: VendorCo
Model: ProductCode
Serial: 4312707004457490
TRAN: usb
RM: 1
```

Antes de ser usado como backup, a capacidade física foi validada com F3:

```bash
sudo f3probe --destructive --time-ops /dev/sdb
```

Resultado observado:

```text
Good news: The device `/dev/sdb' is the real thing
Usable size:    117.19 GB
Announced size: 117.19 GB
Module:         128.00 GB
```

O HD externo de 1 TB permanece como opção futura; ele não é necessário para a capacidade atual do HomeLab.

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

Pendrive USB 128 GB — backup
└── /srv/backup
    ├── restic
    ├── restore-tests
    └── status
```

## Preparação concluída

O dispositivo foi preparado pelo script:

```bash
sudo bash scripts/prepare-backup-disk.sh /dev/sdb
```

Estado validado:

```text
/dev/sdb1
FSTYPE: ext4
LABEL:  HOMELAB_BACKUP
MOUNT:  /srv/backup
SIZE:   ~115G
AVAIL:  ~114G
```

UUID atual:

```text
118e7038-9c56-4ba4-a593-103dc58871af
```

Entrada criada no `/etc/fstab`:

```fstab
UUID=118e7038-9c56-4ba4-a593-103dc58871af /srv/backup ext4 defaults,nofail,x-systemd.automount,x-systemd.device-timeout=10s 0 2
```

Validações executadas com sucesso:

```bash
findmnt /srv/backup
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS,TRAN
df -h /srv/backup
sudo mount -a
sudo ls -lah /srv/backup
```

Diretórios esperados:

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
- verificação periódica do repositório;
- SMART quando a mídia expõe essa funcionalidade.

Pendrives USB normalmente não fornecem SMART. A ausência de SMART não é tratada como falha da rotina; a manutenção continua e registra apenas um aviso.

## Dados protegidos

O backup cobre atualmente:

- repositório e arquivos Compose do HomeLab;
- `/etc/fstab`;
- Netplan;
- Unbound;
- Docker daemon config;
- UFW e `/etc/default/ufw`;
- units do systemd;
- MOTD customizado do HomeLab;
- configuração da rotina de backup, exceto a senha;
- volumes do Portainer;
- volumes do AdGuard Home;
- volume do Uptime Kuma;
- volumes do Beszel Hub e Agent;
- volume do Diun.

O HomeLab Web é estático e já está incluído no próprio repositório do projeto.

Não são incluídos:

- imagens e layers recriáveis do Docker;
- caches e logs temporários;
- o próprio `/srv/backup`;
- `/etc/homelab-backup/restic-password`.

> A senha do Restic deve ser guardada fora do servidor. Sem ela, os snapshots não podem ser restaurados.

## Política

| Rotina | Horário | Ação |
|---|---:|---|
| Backup | diariamente às 03:15 | snapshot criptografado e incremental |
| Manutenção | domingo às 04:30 | retenção, prune, check de 10% e tentativa de SMART |
| Restore test | dia 1 às 05:30 | restauração do snapshot mais recente em diretório isolado |

Retenção:

- 7 snapshots diários;
- 8 semanais;
- 12 mensais;
- 2 anuais.

## Instalar Restic e timers

Com `/srv/backup` montado:

```bash
sudo bash scripts/install-backup-stack.sh
```

Durante a instalação será solicitada uma senha Restic com pelo menos 16 caracteres.

Depois valide:

```bash
systemctl list-timers 'homelab-*' --no-pager
sudo systemctl status homelab-backup.timer
sudo systemctl status homelab-backup-maintenance.timer
sudo systemctl status homelab-restore-test.timer
```

## Primeiro backup

```bash
sudo systemctl start homelab-backup.service
sudo journalctl -u homelab-backup.service -f
```

A rotina interrompe brevemente containers com dados persistentes para produzir uma cópia consistente e os reinicia automaticamente ao final, inclusive em caso de erro.

Valide:

```bash
sudo cat /srv/backup/status/last-success.txt
sudo bash -c 'source /etc/homelab-backup/restic.env; restic snapshots'
sudo bash -c 'source /etc/homelab-backup/restic.env; restic stats --mode restore-size'
```

O backup é cancelado se `/srv/backup` não estiver realmente montado, evitando gravação acidental no armazenamento interno.

## Teste de restauração

```bash
sudo systemctl start homelab-restore-test.service
sudo journalctl -u homelab-restore-test.service --no-pager -n 100
```

Os testes ficam em:

```text
/srv/backup/restore-tests/
```

## Validação real da implantação — 2026-08-11

O primeiro ciclo completo de backup e restauração foi executado manualmente e validado com sucesso.

### Snapshot inicial

```text
Snapshot: a79a4c33
Host:     homelab
Tag:      homelab
Arquivos: 279
Tamanho lógico: 5.878 MiB
```

O repositório Restic ocupou aproximadamente `2,9 MiB` após o primeiro snapshot.

O arquivo de estado registrou:

```text
status=success
started_at=2026-08-11T22:59:50-03:00
finished_at=2026-08-11T23:00:10-03:00
snapshot=a79a4c33
repository=/srv/backup/restic
```

A verificação de integridade foi executada com:

```bash
sudo bash -c '
set -a
source /etc/homelab-backup/restic.env
set +a
restic check
'
```

Resultado:

```text
no errors were found
```

### Restore test

O snapshot `a79a4c33` foi restaurado em:

```text
/srv/backup/restore-tests/20260811-230507
```

O Restic informou:

```text
Summary: Restored 604 files/dirs (5.878 MiB)
```

O script contabilizou `279` arquivos regulares restaurados e criou a evidência:

```text
/srv/backup/restore-tests/20260811-230507/RESTORE_TEST_OK.txt
```

Conteúdo validado:

```text
status=success
finished_at=2026-08-11T23:05:12-03:00
files_restored=279
snapshot=latest
```

O serviço `homelab-restore-test.service` terminou com sucesso e os arquivos restaurados foram verificados em diretório isolado, sem sobrescrever o ambiente de produção.

## Remoção segura da mídia

Antes de retirar o pendrive:

```bash
sudo systemctl stop homelab-backup.timer
sudo systemctl stop homelab-backup-maintenance.timer
sudo systemctl stop homelab-restore-test.timer
sudo sync
sudo umount /srv/backup
```

## Limitações

O pendrive é adequado para o laboratório e para a capacidade atual, mas não substitui uma estratégia 3-2-1. Ele protege contra falhas lógicas, erro de atualização e perda de configuração, porém não protege sozinho contra roubo, incêndio, falha física da própria mídia ou perda da senha Restic.

Como evolução futura, o HD externo de 1 TB pode assumir o papel de segunda mídia ou substituir o pendrive como armazenamento principal de backup.
