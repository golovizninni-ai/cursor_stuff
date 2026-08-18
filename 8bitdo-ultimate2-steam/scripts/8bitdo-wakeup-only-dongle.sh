#!/bin/bash
# Оставить USB-wake только для 8BitDo (VID 2dc8). Всё остальное USB — disabled.
# Кнопка питания / ACPI power — не трогаем, будит как раньше.
#
# Использование:
#   sudo ./8bitdo-wakeup-only-dongle.sh
#   sudo ./8bitdo-wakeup-only-dongle.sh --dry-run

set -euo pipefail

EIGHTBITDO_VID="2dc8"
DRY_RUN=0

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

log() {
  echo "8bitdo-wakeup: $*"
}

set_wakeup() {
  local path="$1"
  local value="$2"
  local label="$3"
  if [[ ! -f "$path" ]]; then
    return 0
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "would set $path -> $value ($label)"
  else
    echo "$value" >"$path" 2>/dev/null || log "skip $path ($label)"
    log "$path -> $value ($label)"
  fi
}

for d in /sys/bus/usb/devices/*; do
  [[ -f "$d/power/wakeup" ]] || continue
  name="$(basename "$d")"

  if [[ -f "$d/idVendor" ]]; then
    vid="$(tr '[:upper:]' '[:lower:]' <"$d/idVendor" | tr -d '[:space:]')"
    pid=""
    [[ -f "$d/idProduct" ]] && pid="$(tr '[:upper:]' '[:lower:]' <"$d/idProduct" | tr -d '[:space:]')"
    if [[ "$vid" == "$EIGHTBITDO_VID" ]]; then
      set_wakeup "$d/power/wakeup" enabled "2dc8:${pid:-?} $name"
    else
      set_wakeup "$d/power/wakeup" disabled "${vid:-?}:${pid:-?} $name"
    fi
  elif [[ "$name" == usb* ]]; then
    # Root hub: disabled — wake только с узла донгла 2dc8 (см. README «минимальный таргет»).
    set_wakeup "$d/power/wakeup" disabled "root-hub $name"
  else
    set_wakeup "$d/power/wakeup" disabled "no-vid $name"
  fi
done

log "done — wake USB: только 2dc8; кнопка питания не затронута"
