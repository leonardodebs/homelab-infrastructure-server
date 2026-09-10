# 21 — Backrest (visualizador do Restic)

## Objetivo

Dar uma interface web para o repositório Restic: navegar snapshots, ver estatísticas, e restaurar arquivos pelo navegador — sem substituir o executor dos backups, que continua sendo o `systemd` ([docs/13-Backup.md](13-Backup.md)).

O [Backrest](https://github.com/garethgeorge/backrest) roda no Dell, monta o repositório **somente leitura** (`/srv/backup/restic`) e fica atrás do Caddy.

## Como funciona

| Item | Valor |
|---|---|
| Container | `backrest` (stack `homelab`, imagem `garethgeorge/backrest` pinada por digest) |
| Porta interna | `127.0.0.1:9898` (só o Caddy alcança) |
| Acesso | `https://backrest.home.arpa` ou `https://192.168.15.2:9899` |
| Repositório montado | `/srv/backup/restic` → `/repos/homelab` **:ro** |
| Senha do repo | `/etc/homelab-backup/restic-password` → `/run/secrets/restic-password` :ro |
| Volumes próprios | `backrest_data`, `backrest_config`, `backrest_cache` |

O mount `:ro` é de propósito: o Backrest só faz operações de leitura (navegar, stats, restore — o restore escreve no destino, não no repo). O `restic-exporter` já monta esse mesmo caminho `:ro` e funciona. **Não** configurar plano de backup nem prune/check agendado no Backrest — isso evita disputa de lock com o `homelab-backup.service`.

## 1. Subir o container

```bash
cd ~/homelab-infrastructure-server
git pull
docker compose --env-file compose/.env -f compose/compose.yaml up -d backrest
docker logs --tail 30 backrest
```

## 2. Liberar a porta no UFW

```bash
sudo ufw allow from 192.168.15.0/24 to any port 9899 proto tcp comment 'Backrest HTTPS (Caddy) LAN'
```

## 3. DNS rewrite no AdGuard Home

**Filters → DNS rewrites → Add**: `backrest.home.arpa` → `192.168.15.2`.

## 4. Recarregar o Caddy

O `git pull` reescreve o `Caddyfile` (bind mount de arquivo único), então:

```bash
docker restart caddy
```

## 5. Primeiro acesso e configuração

1. Abrir `https://backrest.home.arpa` (cadeado válido — a CA do Caddy já está instalada no Windows).
2. Criar o usuário administrador (o Backrest pede na primeira tela).
3. **Add Repo**:
   - URI: `/repos/homelab`
   - Password: no campo de arquivo de senha, informe `/run/secrets/restic-password`.
   - **Flags / extra args**: adicione `--no-lock`. O repositório é montado somente leitura, então o Restic não consegue gravar arquivos de lock — `--no-lock` deixa as operações de leitura (snapshots, ls, stats, restore) funcionarem sem tentar travar o repo.
   - **Não** criar Plan nenhum. Sem prune/check automático (além de o repo `:ro` impedir isso, evita disputa com o `homelab-backup.service`).
   - Se o Backrest reclamar mesmo com `--no-lock`, a alternativa é trocar o mount de `:ro` para `:rw` no `compose.yaml` (o Backrest continua sem plano, então só faz leitura; o lock do Restic serializa com o systemd).
4. Abrir o repo → aba de snapshots. A lista deve bater com `restic snapshots --host homelab --tag homelab` rodado no servidor.

## 6. Testar um restore

Pela UI: escolher um snapshot → navegar até um arquivo pequeno → **Restore** para um diretório temporário (ex.: `/tmp/backrest-teste`) → conferir no servidor que o arquivo saiu íntegro.

## Segurança

- Backrest nunca é exposto direto na LAN — só via Caddy na `9899` (ou hostname na `443`), com o próprio login do Backrest por cima.
- Repo montado `:ro`: o Backrest não consegue apagar snapshots nem alterar o repositório mesmo se comprometido.
- Senha do repo Restic montada `:ro`, fora do compose e fora do git.
- Atualização de imagem: notificada pelo Diun (`diun.enable=true`), aplicada manualmente após backup.

## Validação

- [ ] `docker ps` mostra `backrest` `running`;
- [ ] `https://backrest.home.arpa` e `https://192.168.15.2:9899` abrem com cadeado válido;
- [ ] login do Backrest criado;
- [ ] repo `/repos/homelab` adicionado, **sem plano**;
- [ ] contagem de snapshots no Backrest = `restic snapshots --host homelab --tag homelab`;
- [ ] restore de um arquivo para `/tmp` funciona;
- [ ] `homelab-backup.service` roda normalmente na janela seguinte (sem erro de lock).
