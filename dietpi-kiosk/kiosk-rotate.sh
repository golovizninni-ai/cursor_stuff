#!/bin/bash
# Tab autorotation for Chromium kiosk (reads /etc/kiosk/dashboards.json)
# Target: /usr/local/sbin/kiosk-rotate.sh

set -euo pipefail

export PATH="/usr/sbin:/usr/bin:/bin:${PATH:-}"
export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-/home/dietpi/.Xauthority}"

CFG="${KIOSK_DASHBOARDS:-/etc/kiosk/dashboards.json}"
LOCK="/run/kiosk-rotate.lock"

exec 9>"$LOCK"
flock -n 9 || exit 0

read_cfg() {
  python3 - "$CFG" <<'PY'
import json, sys
path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as f:
        d = json.load(f)
except Exception:
    d = {}
enabled = bool(d.get("rotate_enabled", True))
try:
    sec = int(d.get("rotate_sec", 45))
except (TypeError, ValueError):
    sec = 45
if sec < 5:
    sec = 5
print("1" if enabled else "0", sec)
PY
}

while true; do
  read -r enabled sec < <(read_cfg)
  if [ "$enabled" = "1" ] && [ -S /tmp/.X11-unix/X0 ]; then
    xdotool key --clearmodifiers ctrl+Page_Down >/dev/null 2>&1 || true
  fi
  sleep "$sec"
done
