#!/bin/bash
# Снятие слоя совместимости Bazzite 44 (InputPlumber ignore + wrapper).
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Запустите через sudo: sudo $0" >&2
  exit 1
fi

rm -f /etc/inputplumber/devices.d/19-custom-2dc8_6012.yaml \
      /etc/inputplumber/devices.d/19-custom-2dc8_310b.yaml \
      /usr/local/bin/8bitdo-switch-gamemode

systemctl try-reload-or-restart inputplumber.service 2>/dev/null || true

echo "Removed Bazzite 44 InputPlumber ignore + 8bitdo-switch-gamemode."
echo "User config ~/.config/8bitdo/gamemode.conf оставлен — верните switch_command вручную при необходимости."
