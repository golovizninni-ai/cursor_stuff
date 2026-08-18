#!/bin/bash
# Снять неработающие обходы Steam (пункты 1–3): hide/unbind 6013 и SDL ignore.
# Blacklist в config.vdf правится вручную — скрипт только подскажет путь.
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Запустите через sudo: sudo $0" >&2
  exit 1
fi

rm -f /etc/udev/rules.d/71-8bitdo-hide-dummy.rules \
      /etc/udev/rules.d/72-8bitdo-unbind-dummy.rules

udevadm control --reload
udevadm trigger --subsystem-match=usb --subsystem-match=hidraw --subsystem-match=input || true

# SDL ignore — мог быть у пользователя, не у root
for uhome in /home/* /var/home/*; do
  [[ -d "$uhome" ]] || continue
  f="$uhome/.config/environment.d/99-8bitdo.conf"
  if [[ -f "$f" ]]; then
    rm -f "$f"
    echo "removed $f"
  fi
done
if [[ -f /root/.config/environment.d/99-8bitdo.conf ]]; then
  rm -f /root/.config/environment.d/99-8bitdo.conf
  echo "removed /root/.config/environment.d/99-8bitdo.conf"
fi

echo
echo "udev hide/unbind 6013 и environment.d/99-8bitdo.conf сняты."
echo "Steam blacklist — вручную (Steam закрыт):"
echo "  ~/.local/share/Steam/config/config.vdf"
echo "  ~/.steam/steam/config/config.vdf"
echo "  ~/.var/app/com.valvesoftware.Steam/.local/share/Steam/config/config.vdf"
echo "Найти: grep controller_blacklist <файл>"
echo "Удалить 2dc8/6013 из значения или всю строку, если там только он."
echo "Потом перелогин / reboot для environment.d."
