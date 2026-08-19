#!/bin/bash
# Диагностика USB/ACPI wake для 8BitDo Ultimate 2.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== lsusb 8BitDo ==="
lsusb 2>/dev/null | grep -i 2dc8 || echo "(нет 2dc8 — вставьте донгл / включите геймпад)"
echo ""

echo "=== lsusb -t (где донгл) ==="
lsusb -t 2>/dev/null | head -80 || true
echo ""

echo "=== ACPI XHC (/proc/acpi/wakeup) ==="
if [[ -r /proc/acpi/wakeup ]]; then
  grep -i xhc /proc/acpi/wakeup || echo "(нет строк XHC)"
else
  echo "/proc/acpi/wakeup недоступен"
fi
echo ""

echo "=== USB power/wakeup (enabled) ==="
grep -H ':enabled' /sys/bus/usb/devices/*/power/wakeup 2>/dev/null || echo "(ничего enabled)"
echo ""

echo "=== 8BitDo nodes + hub path ==="
EIGHTBITDO_VID="2dc8"
usb_parent_name() {
  local name="$1"
  if [[ "$name" =~ ^usb[0-9]+$ ]]; then return 1; fi
  if [[ "$name" =~ ^([0-9]+-[0-9]+(\.[0-9]+)*)\.[0-9]+$ ]]; then echo "${BASH_REMATCH[1]}"; return 0; fi
  if [[ "$name" =~ ^([0-9]+)-[0-9]+(\.[0-9]+)*$ ]]; then echo "usb${BASH_REMATCH[1]}"; return 0; fi
  return 1
}

found=0
for d in /sys/bus/usb/devices/*; do
  [[ -f "$d/idVendor" ]] || continue
  vid="$(tr '[:upper:]' '[:lower:]' <"$d/idVendor" | tr -d '[:space:]')"
  [[ "$vid" == "$EIGHTBITDO_VID" ]] || continue
  found=1
  name="$(basename "$d")"
  pid="$(tr '[:upper:]' '[:lower:]' <"$d/idProduct" 2>/dev/null | tr -d '[:space:]' || echo '?')"
  w="?"
  [[ -f "$d/power/wakeup" ]] && w="$(cat "$d/power/wakeup")"
  echo "device $name pid=$pid wakeup=$w"
  cur="$name"
  while [[ -n "$cur" ]]; do
    p="/sys/bus/usb/devices/$cur/power/wakeup"
    if [[ -f "$p" ]]; then
      echo "  path $cur -> $(cat "$p")"
    fi
    if ! cur="$(usb_parent_name "$cur")"; then break; fi
  done
done
[[ "$found" -eq 1 ]] || echo "8BitDo не найден в sysfs"
echo ""

echo "=== systemd wakeup service ==="
systemctl is-enabled 8bitdo-wakeup-only-dongle.service 2>/dev/null || echo "not installed"
echo ""

echo "=== рекомендации ==="
echo "1. BIOS: Wake from USB ON, ErP/EuP OFF"
echo "2. sudo $ROOT/scripts/8bitdo-wakeup-only-dongle.sh"
echo "3. XHC *enabled в /proc/acpi/wakeup (скрипт включает автоматически)"
echo "4. На пути донгл->root все hub должны быть enabled (не только 2dc8 leaf)"
echo "5. Тест: sleep -> снять с дока / Home на геймпаде"
echo ""
echo "Если enabled только leaf 2dc8, а usbN disabled — wake НЕ работает (только кнопка питания)."
