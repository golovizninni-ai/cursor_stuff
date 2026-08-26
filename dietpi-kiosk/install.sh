#!/bin/bash
# Install DietPi SOC dashboard kiosk customizations
# Run as root on DietPi NUC

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

apt-get update
apt-get install -y xdotool unclutter tigervnc-scraping-server etherwake android-tools-adb v4l-utils

install -m 755 "$SCRIPT_DIR/kiosk-session.sh" /usr/local/bin/kiosk-session.sh
install -m 755 "$SCRIPT_DIR/chromium-autostart.sh" \
  /var/lib/dietpi/dietpi-software/installed/chromium-autostart.sh
install -m 755 "$SCRIPT_DIR/refresh-dashboards.sh" /usr/local/sbin/refresh-dashboards.sh
install -m 755 "$SCRIPT_DIR/tv_on.sh" /root/tv_on.sh
install -m 755 "$SCRIPT_DIR/tv_off.sh" /root/tv_off.sh
install -m 755 "$SCRIPT_DIR/tv_ir_power.sh" /root/tv_ir_power.sh
install -m 755 "$SCRIPT_DIR/test-ir-cycle.sh" /root/test-ir-cycle.sh

mkdir -p /root/ir
install -m 755 "$SCRIPT_DIR/ir/capture-xiaomi-power.sh" /root/ir/capture-xiaomi-power.sh
install -m 644 "$SCRIPT_DIR/ir/README.md" /root/ir/README.md
install -m 644 "$SCRIPT_DIR/ir/xiaomi_power.ir.example" /root/ir/xiaomi_power.ir.example

# Remove obsolete audio-jack IR artifacts if present
rm -f /root/ir/generate-xiaomi-power-wav.py \
  /root/ir/xiaomi_power.wav \
  /root/ir/xiaomi_power_36k.wav \
  /root/ir/xiaomi_power_38k.wav
rm -f /root/.asoundrc
# drop softvol control if it was created (ignore errors)
amixer -c 0 sset IRBoost 0% 2>/dev/null || true

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
echo "Cold TV: plug USB IR, run /root/ir/capture-xiaomi-power.sh, then /root/tv_ir_power.sh"
echo "VNC: host=<NUC-IP> port=5900 (MobaXterm: host and port in separate fields)"
