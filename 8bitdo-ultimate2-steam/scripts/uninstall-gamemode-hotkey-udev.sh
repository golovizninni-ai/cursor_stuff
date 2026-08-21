#!/bin/bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Запустите через sudo: sudo $0" >&2
  exit 1
fi

rm -f /etc/udev/rules.d/74-8bitdo-evdev.rules \
      /usr/local/bin/8bitdo-gamemode-chmod-evdev.sh
udevadm control --reload
udevadm trigger --subsystem-match=input --action=add || true
echo "Removed 74-8bitdo-evdev.rules and chmod helper"
