#!/bin/bash
# Install DietPi SOC dashboard kiosk customizations
# Run as root on DietPi NUC

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

apt-get update
apt-get install -y xdotool unclutter tigervnc-scraping-server

install -m 755 "$SCRIPT_DIR/kiosk-session.sh" /usr/local/bin/kiosk-session.sh
install -m 755 "$SCRIPT_DIR/chromium-autostart.sh" \
  /var/lib/dietpi/dietpi-software/installed/chromium-autostart.sh

# Prefer 1080p for weak NUC GPU
if [ -f /boot/dietpi.txt ]; then
  sed -i 's/^SOFTWARE_CHROMIUM_RES_X=.*/SOFTWARE_CHROMIUM_RES_X=1920/' /boot/dietpi.txt
  sed -i 's/^SOFTWARE_CHROMIUM_RES_Y=.*/SOFTWARE_CHROMIUM_RES_Y=1080/' /boot/dietpi.txt
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
