#!/bin/bash
# Nightly refresh of the active dashboard tab (F5 every 30s for 3 minutes)
# Target: /usr/local/sbin/refresh-dashboards.sh
# Cron:   0 0 * * * /usr/local/sbin/refresh-dashboards.sh >>/var/log/refresh-dashboards.log 2>&1

set -euo pipefail

export DISPLAY=:0
export XAUTHORITY=/home/dietpi/.Xauthority

[ -S /tmp/.X11-unix/X0 ] || exit 1

end=$((SECONDS + 180))
while [ "$SECONDS" -lt "$end" ]; do
  # без windowactivate — у xinit/kiosk нет EWMH
  xdotool key --clearmodifiers F5 || true
  sleep 30
done
