#!/bin/bash
# USB wake: геймпад 8BitDo (2dc8) + кнопка питания; мышь/клава — disabled.
# Важно: root/intermediate hubs на пути к донглу должны быть enabled, иначе
# wake с геймпада не дойдёт до CPU (будит только кнопка питания / ACPI).
#
#   sudo ./8bitdo-wakeup-only-dongle.sh
#   sudo ./8bitdo-wakeup-only-dongle.sh --dry-run

set -euo pipefail

EIGHTBITDO_VID="2dc8"
EIGHTBITDO_PIDS="6013 6012 310b"
DRY_RUN=0

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

declare -A ENABLE_PATH=()

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
    if echo "$value" >"$path" 2>/dev/null; then
      log "$path -> $value ($label)"
    else
      log "skip $path ($label)"
    fi
  fi
}

usb_parent_name() {
  local name="$1"
  if [[ "$name" =~ ^usb[0-9]+$ ]]; then
    return 1
  fi
  if [[ "$name" =~ ^([0-9]+-[0-9]+(\.[0-9]+)*)\.[0-9]+$ ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ "$name" =~ ^([0-9]+)-[0-9]+(\.[0-9]+)*$ ]]; then
    echo "usb${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

mark_path_to_root() {
  local name="$1"
  local parent
  while [[ -n "$name" ]]; do
    ENABLE_PATH["$name"]=1
    if ! parent="$(usb_parent_name "$name")"; then
      break
    fi
    name="$parent"
  done
}

find_eightbitdo_nodes() {
  local d vid pid
  for d in /sys/bus/usb/devices/*; do
    [[ -f "$d/idVendor" ]] || continue
    vid="$(tr '[:upper:]' '[:lower:]' <"$d/idVendor" | tr -d '[:space:]')"
    [[ "$vid" == "$EIGHTBITDO_VID" ]] || continue
    pid=""
    [[ -f "$d/idProduct" ]] && pid="$(tr '[:upper:]' '[:lower:]' <"$d/idProduct" | tr -d '[:space:]')"
    echo "$(basename "$d") ${pid:-?}"
  done
}

enable_xhc_wakeup() {
  local line name state
  [[ -r /proc/acpi/wakeup ]] || return 0
  while read -r line; do
    [[ "$line" =~ ^[[:space:]]*(XHC[^[:space:]]*)[[:space:]]+(\\*)?(enabled|disabled) ]] || continue
    name="${BASH_REMATCH[1]}"
    state="${BASH_REMATCH[3]}"
    if [[ "$state" == "disabled" ]]; then
      if [[ "$DRY_RUN" -eq 1 ]]; then
        log "would enable ACPI wakeup: $name"
      elif echo "$name" >/proc/acpi/wakeup 2>/dev/null; then
        log "ACPI /proc/acpi/wakeup: $name -> enabled"
      fi
    fi
  done < /proc/acpi/wakeup
}

# 1) Собрать путь от каждого 8BitDo до root hub
found=0
while read -r node pid; do
  [[ -n "$node" ]] || continue
  found=1
  log "8BitDo node $node (pid $pid) — mark hub path"
  mark_path_to_root "$node"
done < <(find_eightbitdo_nodes)

if [[ "$found" -eq 0 ]]; then
  log "WARN: no 2dc8 device now — plug dongle (idle 6013 ok) and re-run"
fi

# 2) enabled: узлы на пути + все 2dc8
for name in "${!ENABLE_PATH[@]}"; do
  set_wakeup "/sys/bus/usb/devices/$name/power/wakeup" enabled "path $name"
done

for d in /sys/bus/usb/devices/*; do
  [[ -f "$d/idVendor" ]] || continue
  vid="$(tr '[:upper:]' '[:lower:]' <"$d/idVendor" | tr -d '[:space:]')"
  [[ "$vid" == "$EIGHTBITDO_VID" ]] || continue
  name="$(basename "$d")"
  set_wakeup "$d/power/wakeup" enabled "2dc8 $name"
done

# 3) disabled: всё остальное с power/wakeup (мышь, клава, чужие dongle, чужие hub)
for d in /sys/bus/usb/devices/*; do
  [[ -f "$d/power/wakeup" ]] || continue
  name="$(basename "$d")"
  if [[ -n "${ENABLE_PATH[$name]:-}" ]]; then
    continue
  fi
  if [[ -f "$d/idVendor" ]]; then
    vid="$(tr '[:upper:]' '[:lower:]' <"$d/idVendor" | tr -d '[:space:]')"
    if [[ "$vid" == "$EIGHTBITDO_VID" ]]; then
      continue
    fi
    pid=""
    [[ -f "$d/idProduct" ]] && pid="$(tr '[:upper:]' '[:lower:]' <"$d/idProduct" | tr -d '[:space:]')"
    set_wakeup "$d/power/wakeup" disabled "${vid}:${pid} $name"
  else
    set_wakeup "$d/power/wakeup" disabled "hub/other $name"
  fi
done

enable_xhc_wakeup

log "done — wake path: 2dc8 + hubs to root; other USB disabled; power button unchanged"
