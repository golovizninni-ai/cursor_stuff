#!/bin/dash
# DietPi Chromium kiosk autostart
# Target: /var/lib/dietpi/dietpi-software/installed/chromium-autostart.sh
# Enable via: dietpi-autostart -> 11 : Chromium

STARTX='xinit'
[ "$USER" = 'root' ] || STARTX='startx'
exec "$STARTX" /usr/local/bin/kiosk-session.sh -- -nocursor
