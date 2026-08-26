#!/bin/bash
# Kiosk session: 4K TV + Chromium tabs + tab rotation
# Target: /usr/local/bin/kiosk-session.sh
# URLs / rotation: /etc/kiosk/dashboards.json

export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-/home/dietpi/.Xauthority}"
export PATH="/usr/sbin:/usr/bin:/bin:${PATH:-}"

CFG="${KIOSK_DASHBOARDS:-/etc/kiosk/dashboards.json}"

/root/tv_on.sh || true
sleep 3

xrandr --output HDMI-1 --mode 3840x2160 --rate 30.00 || true

xset s off
xset -dpms
xset s noblank
command -v unclutter >/dev/null && unclutter -idle 0 -root &

#x0vncserver -display :0 -localhost no -rfbport 5900 \
#  -PixelFormat rgb565 \
#  -SecurityTypes None &

pkill -f /usr/local/sbin/kiosk-rotate.sh >/dev/null 2>&1 || true
/usr/local/sbin/kiosk-rotate.sh &

PREF="/home/dietpi/.config/chromium/Default/Preferences"
if [ -f "$PREF" ]; then
  sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' "$PREF"
  sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' "$PREF"
fi

load_urls() {
  python3 - "$CFG" <<'PY'
import json, sys
path = sys.argv[1]
fallback = [
    "https://alfa-soc.vls.lan/?orgId=1&from=now-24h&to=now&timezone=Europe%2FMoscow&var-tab=all&refresh=1m&kiosk/",
    "https://alfa-soc.vls.lan/d/mp-overview/maxpatrol-e28094-obzor?orgId=1&from=now-24h&to=now&timezone=Europe%2FMoscow&refresh=1m&kiosk",
    "https://zabbix-ib.vls.lan/",
]
try:
    with open(path, encoding="utf-8") as f:
        urls = json.load(f).get("urls") or []
except Exception:
    urls = []
urls = [u.strip() for u in urls if isinstance(u, str) and u.strip()]
if not urls:
    urls = fallback
for u in urls:
    print(u)
PY
}

while true; do
  mapfile -t URLS < <(load_urls)
  /usr/bin/chromium \
    --start-fullscreen \
    --window-size=3840,2160 \
    --window-position=0,0 \
    --high-dpi-support=1 \
    --noerrdialogs \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --check-for-update-interval=31536000 \
    --ignore-certificate-errors \
    --allow-insecure-localhost \
    --hide-crash-restore-bubble \
    "${URLS[@]}" || true
  sleep 2
done
