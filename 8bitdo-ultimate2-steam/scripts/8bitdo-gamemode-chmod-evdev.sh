#!/bin/bash
# chmod 0666 на /dev/input/event* от 8BitDo Ultimate 2 (6012 / 310b).
# Вызывается из udev и install-gamemode-hotkey-udev.sh.
set -euo pipefail

chmod_node() {
  local dev="$1"
  [[ -e "$dev" ]] || return 0
  chmod a+rw "$dev" 2>/dev/null || chmod 0666 "$dev" 2>/dev/null || true
}

# Если udev передал DEVNAME — только его
if [[ -n "${DEVNAME:-}" ]]; then
  chmod_node "$DEVNAME"
  exit 0
fi

vendor="" product="" name="" events=""
flush() {
  local lname ev
  [[ "$vendor" == "2dc8" ]] || return 0
  [[ "$product" == "6012" || "$product" == "310b" ]] || return 0
  lname=$(echo "$name" | tr '[:upper:]' '[:lower:]')
  [[ "$lname" == *"ultimate 2"* ]] || return 0
  for ev in $events; do
    [[ "$ev" == event* ]] || continue
    chmod_node "/dev/input/$ev"
  done
}

while IFS= read -r line; do
  if [[ -z "$line" ]]; then
    flush
    vendor="" product="" name="" events=""
    continue
  fi
  case "$line" in
    I:*)
      vendor=$(echo "$line" | sed -n 's/.*Vendor=\([0-9a-fA-F]*\).*/\1/p' | tr 'A-F' 'a-f')
      product=$(echo "$line" | sed -n 's/.*Product=\([0-9a-fA-F]*\).*/\1/p' | tr 'A-F' 'a-f')
      ;;
    N:*)
      name=$(echo "$line" | sed 's/^N: Name="//; s/"$//')
      ;;
    H:*)
      events=$(echo "$line" | sed 's/^H: Handlers=//')
      ;;
  esac
done < /proc/bus/input/devices
flush
