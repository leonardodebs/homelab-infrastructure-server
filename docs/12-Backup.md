# 12 — Backup e restauração

## Escopo do backup

O script `scripts/backup.sh` salva:

- arquivos Compose e variáveis de exemplo;
- configuração do Unbound;
- Netplan;
- volume do Portainer;
- volumes do AdGuard Home;
- volume do Uptime Kuma;
- hashes SHA-256 dos arquivos compactados.

## Destino

```text
/opt/homelab/backups/AAAAMMDD-HHMMSS
```

Como o SSD interno é pequeno, copie os backups para outro dispositivo.

## Execução manual

```bash
chmod +x scripts/*.sh
./scripts/backup.sh
```

Valide:

```bash
sudo find /opt/homelab/backups -maxdepth 2 -type f -ls
sudo cat /opt/homelab/backups/ULTIMO_BACKUP/SHA256SUMS
```

## Copiar para o notebook

No PowerShell:

```powershell
scp -r leonardo@192.168.100.10:/opt/homelab/backups/AAAAMMDD-HHMMSS .
```

## Agendamento semanal

```bash
crontab -e
```

Adicione:

```cron
0 3 * * 6 /home/leonardo/homelab-infrastructure-server/scripts/backup.sh >> /var/log/homelab-backup.log 2>&1
```

## Restauração

A restauração interrompe os containers e substitui seus volumes.

```bash
./scripts/restore.sh /opt/homelab/backups/AAAAMMDD-HHMMSS
```

Digite `RESTAURAR` quando solicitado.

## Validação após restauração

```bash
docker ps
./scripts/healthcheck.sh
docker logs --tail 100 adguardhome
docker logs --tail 100 portainer
docker logs --tail 100 uptime-kuma
```

## Política recomendada

- backup antes de qualquer atualização manual;
- backup semanal;
- cópia externa mensal;
- retenção local de 30 dias;
- teste de restauração após mudanças importantes;
- nunca considerar o próprio SSD do Wyse como único local de backup.
