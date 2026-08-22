#!/bin/bash
# Установка: wake только от 8BitDo USB, не от мыши/клавы.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Запустите через sudo: sudo $0" >&2
  exit 1
fi

CONFLICT=/etc/udev/rules.d/10-wakeup-usb-hubs.rules
if [[ -f "$CONFLICT" ]]; then
  echo "WARN: найден $CONFLICT — включает ВСЕ root hub на каждый udev event."
  echo "      Это ломает «только геймпад» (мышь/клава снова будят). Удаляю..."
  rm -f "$CONFLICT"
fi

install -m 0755 "$ROOT/scripts/8bitdo-wakeup-only-dongle.sh" /usr/local/bin/8bitdo-wakeup-only-dongle.sh
install -m 0755 "$ROOT/scripts/8bitdo-wakeup-check.sh" /usr/local/bin/8bitdo-wakeup-check.sh
install -m 0644 "$ROOT/systemd/8bitdo-wakeup-only-dongle.service" /etc/systemd/system/
install -m 0644 "$ROOT/udev/75-8bitdo-wakeup-only.rules" /etc/udev/rules.d/75-8bitdo-wakeup-only.rules

for svc in systemd-suspend systemd-hybrid-sleep systemd-suspend-then-hibernate; do
  install -d "/etc/systemd/system/${svc}.service.d"
  install -m 0644 "$ROOT/systemd/8bitdo-wakeup-resume.conf" \
    "/etc/systemd/system/${svc}.service.d/8bitdo-wakeup.conf"
done

udevadm control --reload
udevadm trigger --subsystem-match=usb --action=add || true

systemctl daemon-reload
systemctl enable --now 8bitdo-wakeup-only-dongle.service
/usr/local/bin/8bitdo-wakeup-only-dongle.sh

echo ""
echo "Installed. Routing re-applies: boot, after resume (ExecStopPost), udev on USB."
echo "Diagnostics: sudo 8bitdo-wakeup-check.sh"
echo ""
echo "Важно: проверяйте wake СРАЗУ после засыпания. После пробуждения без нового"
echo "сна настройки могут быть сброшены ядром, пока не сработает ExecStopPost."
