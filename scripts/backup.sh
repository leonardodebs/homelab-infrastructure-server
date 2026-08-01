#!/usr/bin/env bash
set -Eeuo pipefail

BACKUP_ROOT="/opt/homelab/backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
DEST="$BACKUP_ROOT/$STAMP"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "$DEST"

cp -a "$ROOT_DIR/compose" "$DEST/"
cp -a "$ROOT_DIR/config" "$DEST/"

for volume in portainer_data adguard_work adguard_conf uptime_kuma_data; do
  docker run --rm \
    -v "homelab_${volume}:/source:ro" \
    -v "$DEST:/backup" \
    alpine:3.20 \
    sh -c "cd /source && tar czf /backup/${volume}.tar.gz ."
done

sudo cp -a /etc/unbound/unbound.conf.d "$DEST/unbound-conf.d"
sudo cp -a /etc/netplan "$DEST/netplan"

sha256sum "$DEST"/*.tar.gz >"$DEST/SHA256SUMS"
find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -mtime +30 -exec rm -rf {} +

echo "Backup concluído em $DEST"
