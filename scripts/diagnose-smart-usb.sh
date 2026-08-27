#!/usr/bin/env bash
set -Eeuo pipefail

# Diagnostico do SMART no HD USB de backup.
# So leitura: nao altera nada no sistema nem no disco.
#
# O smart-check.sh do projeto ja tenta "-d sat" como fallback, mas a
# deteccao do disco pode falhar antes disso (ex.: findmnt retornando
# "systemd-1" em vez do device real quando rodado via systemd). Este
# script usa o device fixo /dev/sdb (identificado via lsblk) e testa
# varios protocolos de passthrough USB->SATA, um por um.

MOUNT_POINT="${BACKUP_MOUNT:-/srv/backup}"

fail() {
  echo "ERRO: $*" >&2
  exit 1
}

[[ $EUID -eq 0 ]] || exec sudo bash "$0" "$@"

command -v smartctl >/dev/null 2>&1 || fail "smartctl nao instalado (apt install smartmontools)."

echo "== Disco montado em $MOUNT_POINT =="
mountpoint -q "$MOUNT_POINT" || fail "$MOUNT_POINT nao esta montado."
findmnt "$MOUNT_POINT"

echo
echo "== Discos USB detectados =="
lsblk -o NAME,SIZE,MODEL,SERIAL,TRAN | grep -E 'NAME|usb' || echo "Nenhum disco USB encontrado via lsblk."

echo
read -r -p "Informe o device do disco de backup (ex.: /dev/sdb, sem numero de particao): " DEVICE
[[ -b "$DEVICE" ]] || fail "$DEVICE nao e um device de bloco valido."

echo
echo "== smartctl --scan (o que o smartmontools enxerga sozinho) =="
smartctl --scan || true

echo
echo "== Identificacao basica (smartctl -i) =="
smartctl -i "$DEVICE" 2>&1 || echo "(falhou sem -d)"

declare -a METHODS=(
  "auto (sem -d)"
  "sat"
  "sat,12"
  "sat,16"
  "usbjmicron"
  "usbsunplus"
  "usbcypress"
  "scsi"
)

WORKING=""
for method in "${METHODS[@]}"; do
  echo
  echo "== Tentando: $method =="
  if [[ "$method" == "auto (sem -d)" ]]; then
    if smartctl -H -A "$DEVICE" 2>&1; then
      WORKING="(sem -d, automatico)"
      break
    fi
  else
    if smartctl -d "$method" -H -A "$DEVICE" 2>&1; then
      WORKING="-d $method"
      break
    fi
  fi
done

echo
echo "================================================================"
if [[ -n "$WORKING" ]]; then
  echo "RESULTADO: SMART funciona com '$WORKING' em $DEVICE."
  echo "Proximo passo: atualizar scripts/smart-check.sh para usar esse protocolo."
else
  echo "RESULTADO: nenhum protocolo de passthrough funcionou."
  echo "A ponte USB->SATA deste gabinete provavelmente nao repassa comandos"
  echo "SMART (limitacao de hardware, nao de configuracao). Alternativas:"
  echo "  - trocar o gabinete/adaptador USB-SATA por um com chipset conhecido"
  echo "    (ASMedia, JMicron, Realtek RTL9210 costumam suportar SAT);"
  echo "  - monitorar a saude do disco por outros sinais (erros de leitura/"
  echo "    escrita no dmesg, falhas de backup, idade do disco)."
fi
echo "================================================================"
