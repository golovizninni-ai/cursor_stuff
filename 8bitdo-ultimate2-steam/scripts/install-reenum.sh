#!/bin/bash
# Установка рабочего фикса Steam D-Input: USB reset при появлении 2dc8:6012.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Запустите через sudo: sudo $0" >&2
  exit 1
fi

install -m 0755 "$ROOT/scripts/8bitdo-reenum.sh" /usr/local/bin/8bitdo-reenum.sh
install -m 0644 "$ROOT/udev/73-8bitdo-reenum.rules" /etc/udev/rules.d/73-8bitdo-reenum.rules

# Старые обходы Steam (blacklist / hide 6013 / unbind) на этом железе не работают.
rm -f /etc/udev/rules.d/71-8bitdo-hide-dummy.rules \
      /etc/udev/rules.d/72-8bitdo-unbind-dummy.rules

udevadm control --reload
udevadm trigger --subsystem-match=usb || true

echo "Installed USB re-enum for 2dc8:6012."
echo "Removed leftover hide/unbind 6013 rules if they existed."
