#!/bin/bash
# Install DietPi SOC dashboard kiosk customizations
# Run as root on DietPi NUC

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

apt-get update
apt-get install -y xdotool unclutter tigervnc-scraping-server etherwake android-tools-adb

install -m 755 "$SCRIPT_DIR/kiosk-session.sh" /usr/local/bin/kiosk-session.sh
install -m 755 "$SCRIPT_DIR/chromium-autostart.sh" \
  /var/lib/dietpi/dietpi-software/installed/chromium-autostart.sh
install -m 755 "$SCRIPT_DIR/refresh-dashboards.sh" /usr/local/sbin/refresh-dashboards.sh
install -m 755 "$SCRIPT_DIR/tv_on.sh" /root/tv_on.sh
install -m 755 "$SCRIPT_DIR/tv_off.sh" /root/tv_off.sh

# Midnight refresh: F5 on active tab every 30s for 3 minutes
CRON_LINE='0 0 * * * /usr/local/sbin/refresh-dashboards.sh >>/var/log/refresh-dashboards.log 2>&1'
( crontab -l 2>/dev/null | grep -Fv refresh-dashboards.sh || true
  echo "$CRON_LINE"
) | crontab -
touch /var/log/refresh-dashboards.log

# 4K (kiosk-session.sh also sets xrandr HDMI-1 3840x2160@30)
if [ -f /boot/dietpi.txt ]; then
  sed -i 's/^SOFTWARE_CHROMIUM_RES_X=.*/SOFTWARE_CHROMIUM_RES_X=3840/' /boot/dietpi.txt
  sed -i 's/^SOFTWARE_CHROMIUM_RES_Y=.*/SOFTWARE_CHROMIUM_RES_Y=2160/' /boot/dietpi.txt
fi

# Ensure Chromium kiosk autostart (index 11)
echo 11 > /boot/dietpi/.dietpi-autostart_index

# VNC password for user dietpi (interactive if missing)
if [ ! -f /home/dietpi/.config/tigervnc/passwd ]; then
  echo "Set VNC password for user dietpi:"
  sudo -u dietpi tigervncpasswd
fi

# Disable leftover systemd units from earlier attempts (if present)
systemctl disable --now kiosk-rotate.service 2>/dev/null || true
systemctl disable --now kiosk-vnc.service 2>/dev/null || true

echo "Installed. Reboot to start kiosk: reboot"
echo "VNC: host=<NUC-IP> port=5900 (MobaXterm: host and port in separate fields)"
