# 16 — HD externo dedicado ao backup

Este capítulo adiciona um **HD externo Seagate de 1 TB**, conectado por USB, exclusivamente para proteger o HomeLab. Ele não será usado para arquivos dos notebooks, compartilhamento Samba ou armazenamento pessoal.

## Arquitetura final

```text
SSD interno de 16 GB — produção
├── Ubuntu Server
├── Docker e imagens
├── AdGuard Home
├── Portainer
├── Uptime Kuma
└── Unbound

HD externo de 1 TB — recuperação
├── /srv/backup/restic
├── /srv/backup/restore-tests
└── /srv/backup/status
```

O sistema e os serviços continuam no SSD interno. O HD externo guarda snapshots criptografados e incrementais do HomeLab.

## Componentes da stack

| Componente | Função |
|---|---|
| ext4 | Sistema de arquivos Linux do HD externo |
| `/etc/fstab` | Montagem automática por UUID |
| Restic | Backup incremental, deduplicado e criptografado |
| systemd timers | Agendamento diário, semanal e mensal |
| smartmontools | Leitura da saúde SMART, quando suportada pela ponte USB |
| `flock` | Impede duas rotinas Restic simultâneas |

## Política adotada

| Rotina | Horário | Ação |
|---|---:|---|
| Backup diário | 03:15 | Cria snapshot criptografado |
| Manutenção semanal | domingo, 04:30 | Retenção, prune, check de 10% e SMART |
| Teste de restauração | dia 1, 05:30 | Restaura o snapshot mais recente em pasta isolada |

Retenção:

- 7 snapshots diários;
- 8 semanais;
- 12 mensais;
- 2 anuais.

## Dados protegidos

- repositório e arquivos Compose do HomeLab;
- configuração do Netplan;
- configuração do Unbound;
- configuração do Docker;
- regras do UFW;
- volumes do Portainer;
- volumes do AdGuard Home;
- volume do Uptime Kuma;
- arquivos de configuração da própria rotina de backup, exceto a senha.

Não são incluídos:

- imagens e camadas recriáveis do Docker;
- logs temporários;
- caches;
- o próprio diretório `/srv/backup`;
- o arquivo `/etc/homelab-backup/restic-password`.

> A senha do Restic precisa ser guardada fora do servidor. Sem ela, os snapshots criptografados não podem ser restaurados.

---

## 1. Identificar o HD correto

Conecte o HD e execute:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT,MODEL,SERIAL,TRAN
```

Exemplo esperado:

```text
sda      14.9G disk                         SSD interno
└─sda1   14.9G part ext4   ubuntu-root      /
sdb     931.5G disk                         Seagate USB
└─sdb1  931.5G part ntfs                    /media/...
```

O nome pode ser diferente. Confirme pelo **modelo, capacidade, serial e coluna `TRAN`**.

### Aviso crítico

O próximo procedimento apaga completamente o disco informado. Não execute usando apenas um nome copiado do exemplo.

---

## 2. Preparar e montar o HD

O script possui proteções contra apagar o disco do sistema, exige o disco inteiro e solicita uma confirmação textual.

```bash
cd ~/homelab-infrastructure-server
chmod +x scripts/*.sh
sudo ./scripts/prepare-backup-disk.sh /dev/sdX
```

Substitua `/dev/sdX` pelo disco confirmado no passo anterior.

O script:

1. verifica se o dispositivo existe e é um disco;
2. recusa o disco que contém `/`;
3. recusa discos com partições montadas;
4. mostra modelo, capacidade e serial;
5. cria tabela GPT e uma partição ext4;
6. cria o label `HOMELAB_BACKUP`;
7. adiciona montagem por UUID em `/etc/fstab`;
8. monta em `/srv/backup`;
9. cria os diretórios da stack.

A entrada gerada no `fstab` segue este modelo:

```fstab
UUID=UUID_REAL /srv/backup ext4 defaults,nofail,x-systemd.automount,x-systemd.device-timeout=10s 0 2
```

`nofail` permite que o Ubuntu inicialize mesmo se o HD estiver desconectado. `x-systemd.automount` monta o volume quando o caminho é acessado.

Valide:

```bash
findmnt /srv/backup
lsblk -f
df -h /srv/backup
sudo mount -a
```

O último comando não deve produzir erros.

---

## 3. Verificar a saúde do disco

Instale a stack no passo seguinte ou instale temporariamente o pacote:

```bash
sudo apt update
sudo apt install -y smartmontools
```

Depois execute:

```bash
sudo ./scripts/smart-check.sh
```

Algumas pontes USB não repassam os comandos SMART. O script tenta o modo padrão e depois o protocolo SAT. Falha de leitura SMART não significa automaticamente que o HD está ruim, mas desconexões, erros de I/O ou ruídos mecânicos exigem investigação.

Consulte o kernel:

```bash
sudo dmesg -T | grep -Ei 'usb|uas|reset|I/O error|sd[a-z]'
```

---

## 4. Instalar Restic e os timers

Execute:

```bash
sudo ./scripts/install-backup-stack.sh
```

Durante a instalação será solicitada uma senha Restic com pelo menos 16 caracteres. Guarde-a em um gerenciador de senhas e, preferencialmente, em uma cópia offline.

O instalador cria:

```text
/etc/homelab-backup/
├── restic.env
├── restic-password
└── excludes.txt

/usr/local/sbin/
├── homelab-restic-backup
├── homelab-restic-maintenance
├── homelab-restic-restore-test
└── homelab-smart-check
```

Também instala e habilita:

```text
homelab-backup.timer
homelab-backup-maintenance.timer
homelab-restore-test.timer
```

Confirme:

```bash
systemctl list-timers 'homelab-*' --no-pager
sudo systemctl status homelab-backup.timer
sudo systemctl status homelab-backup-maintenance.timer
sudo systemctl status homelab-restore-test.timer
```

---

## 5. Executar o primeiro backup

```bash
sudo systemctl start homelab-backup.service
sudo journalctl -u homelab-backup.service -f
```

Durante o backup, os containers `adguardhome`, `portainer` e `uptime-kuma` são pausados brevemente para produzir uma cópia consistente dos volumes. O script reinicia apenas os containers que estavam ativos, inclusive quando ocorre erro.

Ao concluir, valide:

```bash
sudo cat /srv/backup/status/last-success.txt
sudo bash -c 'source /etc/homelab-backup/restic.env; restic snapshots'
sudo bash -c 'source /etc/homelab-backup/restic.env; restic stats --mode restore-size'
```

O backup é cancelado quando `/srv/backup` não está montado. Essa proteção impede que o processo grave acidentalmente os snapshots no SSD interno de 16 GB.

---

## 6. Testar restauração

Execute manualmente o teste automatizado:

```bash
sudo systemctl start homelab-restore-test.service
sudo journalctl -u homelab-restore-test.service --no-pager -n 100
```

O resultado será salvo em:

```text
/srv/backup/restore-tests/AAAAMMDD-HHMMSS/
```

Verifique:

```bash
sudo find /srv/backup/restore-tests -maxdepth 2 -name RESTORE_TEST_OK.txt -print -exec cat {} \;
```

Para restaurar um snapshot manualmente em uma pasta isolada:

```bash
sudo ./scripts/restore.sh latest
```

O script não substitui dados ativos. Ele restaura em `/srv/backup/manual-restore/` para revisão antes de qualquer recuperação real.

---

## 7. Executar manutenção

```bash
sudo systemctl start homelab-backup-maintenance.service
sudo journalctl -u homelab-backup-maintenance.service --no-pager -n 200
```

Essa rotina:

1. aplica a retenção;
2. executa `prune` para liberar blocos sem referência;
3. valida metadados e 10% dos pacotes;
4. tenta ler o SMART;
5. exibe espaço e tamanho restaurável.

Uma verificação completa pode ser executada ocasionalmente:

```bash
sudo bash -c 'source /etc/homelab-backup/restic.env; restic check --read-data'
```

Como lê todo o repositório, ela pode levar bastante tempo no Celeron N2807 e no USB.

---

## 8. Monitorar diariamente

```bash
./scripts/healthcheck.sh
systemctl --failed
journalctl -p err..alert --since today
```

Comandos específicos:

```bash
findmnt /srv/backup
df -h /srv/backup
sudo cat /srv/backup/status/last-success.txt
sudo journalctl -u homelab-backup.service --since '2 days ago'
```

Sinais de problema:

- `/srv/backup` ausente;
- mensagens `I/O error`, `USB disconnect` ou `reset SuperSpeed USB device`;
- timer sem execução recente;
- ausência do arquivo `last-success.txt` atualizado;
- `restic check` com erros;
- setores pendentes ou não corrigíveis no SMART.

---

## 9. Trocar ou desconectar o HD

Pare as rotinas:

```bash
sudo systemctl stop homelab-backup.timer
sudo systemctl stop homelab-backup-maintenance.timer
sudo systemctl stop homelab-restore-test.timer
```

Verifique se não há operação ativa:

```bash
systemctl is-active homelab-backup.service
systemctl is-active homelab-backup-maintenance.service
systemctl is-active homelab-restore-test.service
```

Desmonte:

```bash
sudo sync
sudo umount /srv/backup
```

Somente então desconecte o cabo USB.

---

## 10. Limitações e segurança

Este HD protege contra:

- erro de atualização;
- corrupção de configuração;
- exclusão acidental;
- falha lógica de um volume Docker;
- reinstalação do SSD interno.

Ele não protege sozinho contra:

- roubo;
- incêndio;
- descarga elétrica que atinja o Wyse e o HD;
- falha física do próprio HD;
- perda da senha Restic.

O HD e o Wyse devem ficar no nobreak. Para uma estratégia 3-2-1 completa, mantenha futuramente uma segunda cópia criptografada fora do equipamento.

## Referências oficiais

- Restic — preparação do repositório: https://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html
- Restic — backup: https://restic.readthedocs.io/en/stable/040_backup.html
- Restic — retenção: https://restic.readthedocs.io/en/stable/060_forget.html
- Restic — verificação: https://restic.readthedocs.io/en/stable/045_working_with_repos.html
- systemd.timer: https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html
- smartmontools: https://www.smartmontools.org/
