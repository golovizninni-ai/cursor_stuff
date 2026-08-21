#!/bin/bash
# Диагностика Permission denied для gamemode hotkey.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PY="${HOME}/.local/bin/8bitdo-gamemode-hotkey.py"
[[ -x "$PY" ]] || PY="$ROOT/scripts/8bitdo-gamemode-hotkey.py"

echo "=== groups (текущая shell-сессия) ==="
id
echo ""

echo "=== udev rule ==="
if [[ -f /etc/udev/rules.d/74-8bitdo-evdev.rules ]]; then
  echo "OK: /etc/udev/rules.d/74-8bitdo-evdev.rules"
else
  echo "MISSING: /etc/udev/rules.d/74-8bitdo-evdev.rules"
  echo "  fix: sudo $ROOT/scripts/install-gamemode-hotkey-udev.sh"
fi
echo ""

echo "=== 8BitDo event nodes ==="
found=0
denied=0
vendor="" product="" name="" events=""

flush_block() {
  local lname ev dev mode
  if [[ "$vendor" != "2dc8" ]]; then
    return
  fi
  if [[ "$product" != "6012" && "$product" != "310b" ]]; then
    return
  fi
  lname=$(echo "$name" | tr '[:upper:]' '[:lower:]')
  [[ "$lname" == *"ultimate 2"* ]] || return
  for ev in $events; do
    [[ "$ev" == event* ]] || continue
    dev="/dev/input/$ev"
    found=1
    mode="$(stat -c '%a' "$dev" 2>/dev/null || echo '?')"
    echo "--- $dev ($name, pid $product) mode=$mode ---"
    ls -l "$dev" 2>/dev/null || echo "  (missing)"
    if command -v getfacl >/dev/null 2>&1; then
      getfacl "$dev" 2>/dev/null | sed 's/^/  /' || true
    fi
    if [[ -r "$dev" ]]; then
      echo "  read: OK"
    else
      denied=1
      echo "  read: DENIED"
      echo "  fix: sudo $ROOT/scripts/install-gamemode-hotkey-udev.sh"
      echo "       sudo /usr/local/bin/8bitdo-gamemode-chmod-evdev.sh"
    fi
  done
}

while IFS= read -r line; do
  if [[ -z "$line" ]]; then
    flush_block
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
flush_block

if [[ "$found" -eq 0 ]]; then
  echo "Устройства 8BitDo Ultimate 2 не найдены. Включите геймпад (XInput или D-Input) и повторите."
fi
echo ""

echo "=== systemd user service ==="
unit="${HOME}/.config/systemd/user/8bitdo-gamemode-hotkey.service"
if [[ -f "$unit" ]]; then
  if grep -q '^SupplementaryGroups=' "$unit"; then
    echo "BAD: SupplementaryGroups= in user unit → exit 216/GROUP"
    echo "  fix: ./scripts/install-gamemode-hotkey.sh  # reinstall without SupplementaryGroups"
  else
    echo "OK: no SupplementaryGroups= (correct for user units)"
  fi
  grep -E 'ExecStart=' "$unit" || true
else
  echo "unit not installed: $unit"
  echo "  fix: ./scripts/install-gamemode-hotkey.sh"
fi
echo ""

echo "=== python --list-devices ==="
"$PY" --list-devices || true

if [[ "$denied" -eq 1 ]]; then
  echo ""
  echo "Итог: Permission denied. Выполните:"
  echo "  sudo $ROOT/scripts/install-gamemode-hotkey-udev.sh"
  echo "  # включите геймпад, затем:"
  echo "  sudo /usr/local/bin/8bitdo-gamemode-chmod-evdev.sh"
  echo "  systemctl --user restart 8bitdo-gamemode-hotkey.service"
fi
