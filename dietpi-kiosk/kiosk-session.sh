#!/bin/bash
# Kiosk session: 4K TV + Chromium tabs + tab rotation
# Target: /usr/local/bin/kiosk-session.sh
# Requires: /root/tv_on.sh (wake TV via HDMI-CEC or similar)

export DISPLAY="${DISPLAY:-:0}"

/root/tv_on.sh
sleep 3

# 1. ПРИНУДИТЕЛЬНО ПЕРЕКЛЮЧАЕМ СИСТЕМУ В 4K
xrandr --output HDMI-1 --mode 3840x2160 --rate 30.00

xset s off
xset -dpms
xset s noblank
command -v unclutter >/dev/null && unclutter -idle 0 -root &

# 2. НАСТРОЙКА VNC (раскомментировать при необходимости)
#x0vncserver -display :0 -localhost no -rfbport 5900 \
#  -PixelFormat rgb565 \
#  -SecurityTypes None &

(
  sleep 20
  while true; do
    xdotool key --clearmodifiers ctrl+Page_Down
    sleep 45
  done
) &

# Suppress "Restore pages?" after unclean shutdown
PREF="/home/dietpi/.config/chromium/Default/Preferences"
if [ -f "$PREF" ]; then
  sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' "$PREF"
  sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' "$PREF"
fi

# 3. ЗАПУСК CHROMIUM В 4K С МАСШТАБИРОВАНИЕМ И ИГНОРИРОВАНИЕМ ОШИБОК
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
  "https://alfa-soc.vls.lan/?orgId=1&from=now-24h&to=now&timezone=Europe%2FMoscow&var-tab=all&refresh=1m&kiosk/" \
  "https://alfa-soc.vls.lan/d/mp-overview/maxpatrol-e28094-obzor?orgId=1&from=now-24h&to=now&timezone=Europe%2FMoscow&refresh=1m&kiosk" \
  "https://zabbix-ib.vls.lan/"
