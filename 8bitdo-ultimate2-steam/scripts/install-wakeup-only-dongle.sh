#!/bin/bash
# Установка: wake только от 8BitDo USB, не от мыши/клавы.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Запустите через sudo: sudo $0" >&2
  exit 1
fi

install -m 0755 "$ROOT/scripts/8bitdo-wakeup-only-dongle.sh" /usr/local/bin/
install -m 0644 "$ROOT/systemd/8bitdo-wakeup-only-dongle.service" /etc/systemd/system/

systemctl daemon-reload
systemctl enable --now 8bitdo-wakeup-only-dongle.service

echo "Installed. Check: grep enabled /sys/bus/usb/devices/*/power/wakeup 2>/dev/null | grep -v 2dc8 || true"
