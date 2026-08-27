#!/usr/bin/env bash
set -Eeuo pipefail

OUT_FILE="${1:-./caddy-root-ca.crt}"

docker cp caddy:/data/caddy/pki/authorities/local/root.crt "$OUT_FILE"
echo "CA raiz exportada para $OUT_FILE"
echo "Copie este arquivo para os dispositivos clientes e instale como autoridade confiável."
