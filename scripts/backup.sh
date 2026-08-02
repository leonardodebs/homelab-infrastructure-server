#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $EUID -ne 0 ]]; then
  exec sudo "$0" "$@"
fi

if [[ -x /usr/local/sbin/homelab-restic-backup ]]; then
  exec /usr/local/sbin/homelab-restic-backup "$@"
fi

exec "$SCRIPT_DIR/restic-backup.sh" "$@"
