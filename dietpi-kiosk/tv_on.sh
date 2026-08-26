#!/bin/bash
# Wake Xiaomi (MediaTek) TV: soft (standby) or cold (after power loss)
# Target: /root/tv_on.sh
#
# Soft path (ADB already up): wake + HDMI 3
# Cold path: WOL + USB IR Power (/root/tv_ir_power.sh) + wait ADB + wake + HDMI 3
#
# WOL/ADB alone cannot cold-boot a fully powered-off TV.

set -euo pipefail

export PATH="/usr/sbin:/usr/bin:/bin:${PATH:-}"

TV_ADB="${TV_ADB:-192.168.0.2:5555}"
TV_MAC="${TV_MAC:-d4:5e:ec:f5:01:0d}"
TV_IFACE="${TV_IFACE:-eth0}"
ADB_WAIT_SEC="${ADB_WAIT_SEC:-120}"
ADB_POLL_SEC="${ADB_POLL_SEC:-5}"

adb_online() {
  adb connect "$TV_ADB" >/dev/null 2>&1 || true
  adb devices 2>/dev/null | grep -qE "^${TV_ADB}[[:space:]]+device$"
}

wait_for_adb() {
  local deadline=$((SECONDS + ADB_WAIT_SEC))
  echo "Waiting up to ${ADB_WAIT_SEC}s for ADB ${TV_ADB}..."
  while [ "$SECONDS" -lt "$deadline" ]; do
    if adb_online; then
      echo "ADB online: $TV_ADB"
      return 0
    fi
    sleep "$ADB_POLL_SEC"
    adb connect "$TV_ADB" >/dev/null 2>&1 || true
  done
  echo "ERROR: ADB not ready after ${ADB_WAIT_SEC}s (TV still cold / IR missing?)" >&2
  return 1
}

switch_hdmi3() {
  # Xiaomi MediaTek source picker -> tap HDMI 3 tile
  adb shell am start -a com.mitv.tvhome.atv.app.tv.INPUTSOURCE_POPUP
  sleep 1
  # UI grid tile "HDMI 3" bounds [480,280][800,540] @ 1920x1080
  adb shell input tap 640 410
}

wake_and_hdmi() {
  adb shell input keyevent 224
  sleep 2
  switch_hdmi3
}

# --- soft path: TV already in network standby / Android up ---
if adb_online; then
  echo "Soft wake: ADB already online"
  wake_and_hdmi
  exit 0
fi

# --- cold path ---
echo "Cold path: ADB down — trying WOL + USB IR Power"
etherwake -i "$TV_IFACE" "$TV_MAC" || true
sleep 2

if [ -x /root/tv_ir_power.sh ]; then
  /root/tv_ir_power.sh || true
else
  echo "WARN: /root/tv_ir_power.sh missing — cannot IR-power cold TV" >&2
fi

wait_for_adb
wake_and_hdmi
