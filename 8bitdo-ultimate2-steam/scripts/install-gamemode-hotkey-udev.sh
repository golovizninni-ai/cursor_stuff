#!/bin/bash
# udev + chmod: права evdev для Guide+LT+RT hotkey (fix Permission denied).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RULE=/etc/udev/rules.d/74-8bitdo-evdev.rules
CHMOD=/usr/local/bin/8bitdo-gamemode-chmod-evdev.sh

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Запустите через sudo: sudo $0" >&2
  exit 1
fi

install -m 0644 "$ROOT/udev/74-8bitdo-evdev.rules" "$RULE"
install -m 0755 "$ROOT/scripts/8bitdo-gamemode-chmod-evdev.sh" "$CHMOD"

udevadm control --reload
udevadm trigger --subsystem-match=input --action=add || true
"$CHMOD"

echo "Installed $RULE and $CHMOD"
echo "Переподключите геймпад (выкл/вкл), затем:"
echo "  ./scripts/8bitdo-gamemode-check-perms.sh"
echo "  systemctl --user restart 8bitdo-gamemode-hotkey.service"
echo ""
echo "Ожидаемо: ls -l /dev/input/event* → crw-rw-rw- (или ACL + read OK)"
