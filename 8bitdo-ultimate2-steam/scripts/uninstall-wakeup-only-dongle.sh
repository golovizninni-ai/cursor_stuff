#!/bin/bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Запустите через sudo: sudo $0" >&2
  exit 1
fi

systemctl disable --now 8bitdo-wakeup-only-dongle.service 2>/dev/null || true
rm -f /etc/systemd/system/8bitdo-wakeup-only-dongle.service \
      /etc/udev/rules.d/75-8bitdo-wakeup-only.rules \
      /usr/local/bin/8bitdo-wakeup-only-dongle.sh \
      /usr/local/bin/8bitdo-wakeup-check.sh

for svc in systemd-suspend systemd-hybrid-sleep systemd-suspend-then-hibernate; do
  rm -f "/etc/systemd/system/${svc}.service.d/8bitdo-wakeup.conf"
done

udevadm control --reload
systemctl daemon-reload
echo "Removed 8bitdo wakeup-only install."
