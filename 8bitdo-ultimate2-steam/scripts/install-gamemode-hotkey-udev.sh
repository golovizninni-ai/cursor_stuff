#!/bin/bash
# udev: права evdev для 8BitDo Ultimate 2 (fix Permission denied на Bazzite).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RULE=/etc/udev/rules.d/74-8bitdo-evdev.rules

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Запустите через sudo: sudo $0" >&2
  exit 1
fi

install -m 0644 "$ROOT/udev/74-8bitdo-evdev.rules" "$RULE"
udevadm control --reload
udevadm trigger --subsystem-match=input --action=add || true

echo "Installed $RULE"
echo "Переподключите геймпад (выкл/вкл) или выполните: sudo udevadm trigger --subsystem-match=input"
echo "Проверка: ./scripts/8bitdo-gamemode-check-perms.sh"
