#!/bin/bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Запустите через sudo: sudo $0" >&2
  exit 1
fi

rm -f /usr/local/bin/8bitdo-reenum.sh \
      /etc/udev/rules.d/73-8bitdo-reenum.rules

udevadm control --reload
udevadm trigger --subsystem-match=usb || true

echo "Removed 8bitdo USB re-enum hook."
