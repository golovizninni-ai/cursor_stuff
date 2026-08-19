#!/bin/bash
# Установка: wake только от 8BitDo USB, не от мыши/клавы.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Запустите через sudo: sudo $0" >&2
  exit 1
fi

install -m 0755 "$ROOT/scripts/8bitdo-wakeup-only-dongle.sh" /usr/local/bin/8bitdo-wakeup-only-dongle.sh
install -m 0755 "$ROOT/scripts/8bitdo-wakeup-check.sh" /usr/local/bin/8bitdo-wakeup-check.sh
install -m 0644 "$ROOT/systemd/8bitdo-wakeup-only-dongle.service" /etc/systemd/system/

for svc in systemd-suspend systemd-hybrid-sleep systemd-suspend-then-hibernate; do
  install -d "/etc/systemd/system/${svc}.service.d"
  install -m 0644 "$ROOT/systemd/8bitdo-wakeup-resume.conf" \
    "/etc/systemd/system/${svc}.service.d/8bitdo-wakeup.conf"
done

systemctl daemon-reload
systemctl enable --now 8bitdo-wakeup-only-dongle.service
/usr/local/bin/8bitdo-wakeup-only-dongle.sh

echo "Installed. Diagnostics: sudo 8bitdo-wakeup-check.sh"
