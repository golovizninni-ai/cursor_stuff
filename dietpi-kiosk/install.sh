#!/bin/bash
# Install DietPi SOC dashboard kiosk customizations
# Run as root on DietPi NUC

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

apt-get update
apt-get install -y xdotool unclutter tigervnc-scraping-server etherwake android-tools-adb v4l-utils python3-pam

install -m 755 "$SCRIPT_DIR/kiosk-session.sh" /usr/local/bin/kiosk-session.sh
install -m 755 "$SCRIPT_DIR/chromium-autostart.sh" \
  /var/lib/dietpi/dietpi-software/installed/chromium-autostart.sh
install -m 755 "$SCRIPT_DIR/refresh-dashboards.sh" /usr/local/sbin/refresh-dashboards.sh
install -m 755 "$SCRIPT_DIR/tv_on.sh" /root/tv_on.sh
install -m 755 "$SCRIPT_DIR/tv_off.sh" /root/tv_off.sh
install -m 755 "$SCRIPT_DIR/tv_ir_power.sh" /root/tv_ir_power.sh
install -m 755 "$SCRIPT_DIR/test-ir-cycle.sh" /root/test-ir-cycle.sh
install -m 755 "$SCRIPT_DIR/tv_message.sh" /root/tv_message.sh
install -m 755 "$SCRIPT_DIR/tv_healthcheck.sh" /root/tv_healthcheck.sh
install -m 755 "$SCRIPT_DIR/tv_hdmi_watchdog.sh" /root/tv_hdmi_watchdog.sh

mkdir -p /root/ir
install -m 755 "$SCRIPT_DIR/ir/capture-xiaomi-power.sh" /root/ir/capture-xiaomi-power.sh
install -m 644 "$SCRIPT_DIR/ir/README.md" /root/ir/README.md
install -m 644 "$SCRIPT_DIR/ir/xiaomi_power.ir.example" /root/ir/xiaomi_power.ir.example

# Web panel (PWA over HTTPS — use wildcard *.vls.lan certs in /etc/tv-panel/)
mkdir -p /usr/local/lib/tv_panel/icons /etc/tv-panel
install -m 644 "$SCRIPT_DIR/tv_panel/server.py" /usr/local/lib/tv_panel/server.py
install -m 644 "$SCRIPT_DIR/tv_panel/index.html" /usr/local/lib/tv_panel/index.html
install -m 644 "$SCRIPT_DIR/tv_panel/message.html" /usr/local/lib/tv_panel/message.html
install -m 644 "$SCRIPT_DIR/tv_panel/manifest.webmanifest" /usr/local/lib/tv_panel/manifest.webmanifest
install -m 644 "$SCRIPT_DIR/tv_panel/sw.js" /usr/local/lib/tv_panel/sw.js
install -m 644 "$SCRIPT_DIR/tv_panel/icons/icon-192.png" /usr/local/lib/tv_panel/icons/icon-192.png
install -m 644 "$SCRIPT_DIR/tv_panel/icons/icon-512.png" /usr/local/lib/tv_panel/icons/icon-512.png
if [ -f "$SCRIPT_DIR/certs/website.crt" ] && [ -f "$SCRIPT_DIR/certs/website.key" ]; then
  install -m 644 "$SCRIPT_DIR/certs/website.crt" /etc/tv-panel/cert.pem
  install -m 640 "$SCRIPT_DIR/certs/website.key" /etc/tv-panel/key.pem
fi
if [ ! -f /etc/tv-panel/cert.pem ] || [ ! -f /etc/tv-panel/key.pem ]; then
  echo "ERROR: missing TLS certs. Put wildcard cert at /etc/tv-panel/cert.pem + key.pem" >&2
  echo "  (or dietpi-kiosk/certs/website.crt + website.key before install)" >&2
  exit 1
fi
install -m 644 "$SCRIPT_DIR/tv-panel.service" /etc/systemd/system/tv-panel.service
systemctl daemon-reload
systemctl enable --now tv-panel.service
systemctl restart tv-panel.service

# Autofix on by default
touch /root/tv_autofix.enabled

# Remove obsolete audio-jack IR artifacts if present
rm -f /root/ir/generate-xiaomi-power-wav.py \
  /root/ir/xiaomi_power.wav \
  /root/ir/xiaomi_power_36k.wav \
  /root/ir/xiaomi_power_38k.wav
rm -f /root/.asoundrc
amixer -c 0 sset IRBoost 0% 2>/dev/null || true

# Crontab: midnight refresh + work-hours ADB health + HDMI watchdog
(
  crontab -l 2>/dev/null \
    | grep -Fv refresh-dashboards.sh \
    | grep -Fv tv_healthcheck.sh \
    | grep -Fv tv_hdmi_watchdog.sh \
    || true
  echo '0 0 * * * /usr/local/sbin/refresh-dashboards.sh >>/var/log/refresh-dashboards.log 2>&1'
  echo '* 9-17 * * 1-5 /root/tv_healthcheck.sh'
  echo '30-59 8 * * 1-5 /root/tv_healthcheck.sh'
  echo '0-30 18 * * 1-5 /root/tv_healthcheck.sh'
  echo '*/5 9-17 * * 1-5 /root/tv_hdmi_watchdog.sh'
  echo '30,35,40,45,50,55 8 * * 1-5 /root/tv_hdmi_watchdog.sh'
  echo '0,5,10,15,20,25,30 18 * * 1-5 /root/tv_hdmi_watchdog.sh'
) | crontab -
touch /var/log/refresh-dashboards.log

# 4K (kiosk-session.sh also sets xrandr HDMI-1 3840x2160@30)
if [ -f /boot/dietpi.txt ]; then
  sed -i 's/^SOFTWARE_CHROMIUM_RES_X=.*/SOFTWARE_CHROMIUM_RES_X=3840/' /boot/dietpi.txt
  sed -i 's/^SOFTWARE_CHROMIUM_RES_Y=.*/SOFTWARE_CHROMIUM_RES_Y=2160/' /boot/dietpi.txt
fi

echo 11 > /boot/dietpi/.dietpi-autostart_index

if [ ! -f /home/dietpi/.config/tigervnc/passwd ]; then
  echo "Set VNC password for user dietpi:"
  sudo -u dietpi tigervncpasswd
fi

systemctl disable --now kiosk-rotate.service 2>/dev/null || true
systemctl disable --now kiosk-vnc.service 2>/dev/null || true

echo "Installed. Reboot to start kiosk: reboot"
echo "TV panel (PWA): https://ozii-dash.vls.lan:8787/  (root/dietpi PAM)"
echo "Cold TV: plug USB IR, run /root/ir/capture-xiaomi-power.sh, then /root/tv_ir_power.sh"
echo "VNC: host=<NUC-IP> port=5900 (MobaXterm: host and port in separate fields)"
