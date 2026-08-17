#!/bin/bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Запустите через sudo: sudo $0" >&2
  exit 1
fi

rm -f /usr/local/bin/8bitdo-pre-suspend.sh \
      /usr/local/bin/8bitdo-post-resume.sh \
      /usr/local/lib/8bitdo-common.sh

for svc in systemd-suspend systemd-hybrid-sleep systemd-suspend-then-hibernate; do
  rm -f "/etc/systemd/system/${svc}.service.d/8bitdo.conf"
  rmdir "/etc/systemd/system/${svc}.service.d" 2>/dev/null || true
done

systemctl daemon-reload
echo "8bitdo sleep hooks removed. Config /etc/8bitdo-sleep.conf left in place."
