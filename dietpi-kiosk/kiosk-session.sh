#!/bin/bash
# Kiosk session: Chromium tabs + VNC scrape of :0 + tab rotation
# Target: /usr/local/bin/kiosk-session.sh

export DISPLAY="${DISPLAY:-:0}"

xset s off
xset -dpms
xset s noblank
command -v unclutter >/dev/null && unclutter -idle 0 -root &

# Share the same screen as the TV (port 5900)
x0vncserver -display :0 -localhost no -rfbport 5900 \
  -PasswordFile /home/dietpi/.config/tigervnc/passwd &

# Rotate tabs every 45 seconds
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

/usr/bin/chromium \
  --start-fullscreen \
  --window-size=1920,1080 \
  --window-position=0,0 \
  --noerrdialogs \
  --disable-infobars \
  --hide-crash-restore-bubble \
  --disable-session-crashed-bubble \
  --check-for-update-interval=31536000 \
  --ignore-certificate-errors \
  --allow-insecure-localhost \
  "https://alfa-soc.vls.lan/" \
  "https://alfa-siem-pt.vls.lan/#/dashboards/dashboard?dashboardId=74" \
  "https://zabbix-ib.vls.lan/"
