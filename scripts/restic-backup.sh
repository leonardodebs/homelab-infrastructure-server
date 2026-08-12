#!/usr/bin/env bash
set -Eeuo pipefail

ENV_FILE="/etc/homelab-backup/restic.env"
EXCLUDES_FILE="/etc/homelab-backup/excludes.txt"
LOCK_FILE="/run/lock/homelab-restic.lock"
STATE_DIR="/var/lib/homelab-backup"

fail() {
  echo "ERRO: $*" >&2
  exit 1
}

[[ $EUID -eq 0 ]] || fail "Execute como root."
[[ -r "$ENV_FILE" ]] || fail "Arquivo ausente: $ENV_FILE. Execute install-backup-stack.sh."

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${RESTIC_REPOSITORY:?RESTIC_REPOSITORY não definido}"
: "${RESTIC_PASSWORD_FILE:?RESTIC_PASSWORD_FILE não definido}"
: "${RESTIC_CACHE_DIR:?RESTIC_CACHE_DIR não definido}"
: "${HOMELAB_PROJECT_DIR:?HOMELAB_PROJECT_DIR não definido}"
: "${BACKUP_MOUNT:=/srv/backup}"

mountpoint -q "$BACKUP_MOUNT" || fail "$BACKUP_MOUNT não está montado. Backup cancelado para não gravar no armazenamento interno."
[[ -r "$RESTIC_PASSWORD_FILE" ]] || fail "Arquivo de senha não encontrado: $RESTIC_PASSWORD_FILE"
[[ -r "$EXCLUDES_FILE" ]] || fail "Arquivo de exclusões não encontrado: $EXCLUDES_FILE"
[[ -d "$HOMELAB_PROJECT_DIR" ]] || fail "Diretório do projeto não encontrado: $HOMELAB_PROJECT_DIR"

mkdir -p "$RESTIC_CACHE_DIR" "$STATE_DIR" "$BACKUP_MOUNT/status"
chmod 0700 "$RESTIC_CACHE_DIR" "$STATE_DIR"

exec 9>"$LOCK_FILE"
flock -n 9 || fail "Já existe outra operação Restic em execução."

# Containers com estado persistente que são interrompidos brevemente para que os
# respectivos volumes sejam copiados em um ponto consistente.
RUNNING_CONTAINERS=()
restart_containers() {
  local container
  for container in "${RUNNING_CONTAINERS[@]:-}"; do
    [[ -n "$container" ]] || continue
    docker start "$container" >/dev/null 2>&1 || true
  done
}
trap restart_containers EXIT INT TERM

if systemctl is-active --quiet docker; then
  for container in \
    adguardhome \
    portainer \
    uptime-kuma \
    beszel \
    beszel-agent \
    diun
  do
    if docker ps --format '{{.Names}}' | grep -Fxq "$container"; then
      RUNNING_CONTAINERS+=("$container")
    fi
  done

  if ((${#RUNNING_CONTAINERS[@]} > 0)); then
    echo "Pausando brevemente containers para obter dados consistentes: ${RUNNING_CONTAINERS[*]}"
    docker stop --time 30 "${RUNNING_CONTAINERS[@]}" >/dev/null
  fi
fi

# Configuração do host e do projeto. O portal HomeLab é estático e já está
# incluído dentro de HOMELAB_PROJECT_DIR.
SOURCES=(
  "$HOMELAB_PROJECT_DIR"
  "/etc/fstab"
  "/etc/netplan"
  "/etc/unbound"
  "/etc/docker"
  "/etc/ufw"
  "/etc/default/ufw"
  "/etc/systemd/system"
  "/etc/update-motd.d/99-homelab"
  "/etc/homelab-backup/restic.env"
  "/etc/homelab-backup/excludes.txt"
)

# Volumes persistentes existentes na stack atual. Não são copiadas imagens,
# layers ou containers recriáveis do Docker.
for volume in \
  homelab_portainer_data \
  homelab_adguard_work \
  homelab_adguard_conf \
  homelab_uptime_kuma_data \
  homelab_beszel_data \
  homelab_beszel_agent_data \
  homelab_diun_data
do
  if docker volume inspect "$volume" >/dev/null 2>&1; then
    mountpoint_path="$(docker volume inspect -f '{{.Mountpoint}}' "$volume")"
    [[ -d "$mountpoint_path" ]] && SOURCES+=("$mountpoint_path")
  else
    echo "AVISO: volume Docker ainda não existe: $volume"
  fi
done

for source in "${SOURCES[@]}"; do
  [[ -e "$source" ]] || echo "AVISO: origem ainda não existe e será ignorada: $source"
done

VALID_SOURCES=()
for source in "${SOURCES[@]}"; do
  [[ -e "$source" ]] && VALID_SOURCES+=("$source")
done

((${#VALID_SOURCES[@]} > 0)) || fail "Nenhuma origem válida foi encontrada."

HOST_TAG="$(hostname --short)"
STARTED_AT="$(date --iso-8601=seconds)"

echo "Iniciando backup Restic em $STARTED_AT"
nice -n 10 ionice -c2 -n7 restic backup \
  --host "$HOST_TAG" \
  --tag homelab \
  --exclude-file "$EXCLUDES_FILE" \
  --exclude "$RESTIC_PASSWORD_FILE" \
  "${VALID_SOURCES[@]}"

restic forget \
  --host "$HOST_TAG" \
  --tag homelab \
  --keep-daily 7 \
  --keep-weekly 8 \
  --keep-monthly 12 \
  --keep-yearly 2

FINISHED_AT="$(date --iso-8601=seconds)"
LATEST_SNAPSHOT="$(restic snapshots --host "$HOST_TAG" --tag homelab --latest 1 --json | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data[0]["short_id"] if data else "unknown")')"

cat >"$STATE_DIR/last-success" <<EOF
status=success
started_at=$STARTED_AT
finished_at=$FINISHED_AT
snapshot=$LATEST_SNAPSHOT
repository=$RESTIC_REPOSITORY
EOF

cp "$STATE_DIR/last-success" "$BACKUP_MOUNT/status/last-success.txt"
sync

echo "Backup concluído. Snapshot: $LATEST_SNAPSHOT"
