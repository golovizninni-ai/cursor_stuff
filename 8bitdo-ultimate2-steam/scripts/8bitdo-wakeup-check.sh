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

echo "=== конфликтующие udev rules ==="
for f in /etc/udev/rules.d/10-wakeup-usb-hubs.rules /etc/udev/rules.d/75-8bitdo-wakeup-only.rules; do
  if [[ -f "$f" ]]; then
    echo "  $f"
  fi
done
if [[ -f /etc/udev/rules.d/10-wakeup-usb-hubs.rules ]]; then
  echo "  WARN: 10-wakeup-usb-hubs.rules ломает «только геймпад» — удалите или install-wakeup-only-dongle.sh уберёт"
fi
if [[ ! -f /etc/udev/rules.d/75-8bitdo-wakeup-only.rules ]]; then
  echo "  MISSING: 75-8bitdo-wakeup-only.rules — sudo ./scripts/install-wakeup-only-dongle.sh"
fi
echo ""

echo "=== suspend hooks (нужен ExecStopPost) ==="
for svc in systemd-suspend systemd-hybrid-sleep; do
  f="/etc/systemd/system/${svc}.service.d/8bitdo-wakeup.conf"
  if [[ -f "$f" ]]; then
    echo "  $f:"
    grep -E 'ExecStartPre|ExecStopPost|ExecStart=' "$f" | sed 's/^/    /'
  else
    echo "  MISSING: $f"
  fi
done
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

echo "=== enabled НЕ 8BitDo (лишние источники wake) ==="
extra=0
for d in /sys/bus/usb/devices/*; do
  [[ -f "$d/power/wakeup" ]] || continue
  [[ "$(cat "$d/power/wakeup" 2>/dev/null)" == "enabled" ]] || continue
  name="$(basename "$d")"
  if [[ -f "$d/idVendor" ]]; then
    vid="$(tr '[:upper:]' '[:lower:]' <"$d/idVendor" | tr -d '[:space:]')"
    pid="$(tr '[:upper:]' '[:lower:]' <"$d/idProduct" 2>/dev/null | tr -d '[:space:]' || echo '?')"
    if [[ "$vid" != "2dc8" ]]; then
      extra=1
      echo "  $name  ${vid}:${pid}  $(lsusb -s "${name%%-*}:" 2>/dev/null | sed 's/^[^ ]* //' || echo '?')"
    fi
  else
    # hub — показываем только если не на пути к 8bitdo (упрощённо: все enabled hub)
    extra=1
    echo "  $name  (hub/other)"
  fi
done
[[ "$extra" -eq 0 ]] && echo "  (нет лишних enabled leaf 2dc8-устройств)"
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

echo "=== мышь / клава / Logitech (должны быть disabled) ==="
for d in /sys/bus/usb/devices/*; do
  [[ -f "$d/idVendor" && -f "$d/power/wakeup" ]] || continue
  vid="$(tr '[:upper:]' '[:lower:]' <"$d/idVendor" | tr -d '[:space:]')"
  [[ "$vid" == "2dc8" ]] && continue
  name="$(basename "$d")"
  pid="$(tr '[:upper:]' '[:lower:]' <"$d/idProduct" 2>/dev/null | tr -d '[:space:]' || echo '?')"
  w="$(cat "$d/power/wakeup")"
  # частые: Logitech 046d, клавы 046d/1a2c/04d9/05ac/...
  label=""
  case "$vid" in
    046d) label=" (Logitech — мышь/клава/свисток)" ;;
    1a2c|04d9|05ac|1c4f|258a|0c45) label=" (часто клавиатура)" ;;
  esac
  if [[ "$w" == "enabled" ]]; then
    echo "  BAD  $name ${vid}:${pid} wakeup=enabled${label}  ← будит от стола"
  else
    echo "  OK   $name ${vid}:${pid} wakeup=disabled${label}"
  fi
done
echo ""

echo "=== Wake-on-LAN / PCI (скрипт НЕ трогает) ==="
echo "  USB-скрипт не меняет ethernet/PCI. WoL остаётся как в BIOS/ethtool."
if command -v ethtool >/dev/null 2>&1; then
  for iface in /sys/class/net/*; do
    [[ -d "$iface/device" ]] || continue
    ifn="$(basename "$iface")"
    [[ "$ifn" == "lo" ]] && continue
    wol="$(ethtool "$ifn" 2>/dev/null | grep -i wake-on || true)"
    [[ -n "$wol" ]] && echo "  $ifn: $wol"
  done
else
  echo "  (ethtool нет — смотрите BIOS Wake-on-LAN)"
fi
echo ""

echo "=== почему «то работает, то нет» ==="
echo "- После resume ядро сбрасывает power/wakeup → нужен ExecStopPost + udev 75-*"
echo "- 10-wakeup-usb-hubs.rules включает все root hub обратно"
echo "- Тест: усыпить → сразу пробовать клаву/мышь (не должны будить) и Home на 8BitDo"
echo ""
echo "=== fix ==="
echo "sudo $ROOT/scripts/install-wakeup-only-dongle.sh"
echo "sudo $ROOT/scripts/8bitdo-wakeup-only-dongle.sh"
echo "journalctl -t 8bitdo-wakeup -b"
