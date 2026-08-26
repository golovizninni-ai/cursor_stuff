#!/bin/bash
# Ensure Xiaomi TV stays on HDMI 3 (MediaTek HW4).
# Cron: every 5 min Mon–Fri 08:30–18:30. No logs.
# Target: /root/tv_hdmi_watchdog.sh

set -euo pipefail

TV_ADB="${TV_ADB:-192.168.0.2:5555}"
AUTOFIX_FLAG="${AUTOFIX_FLAG:-/root/tv_autofix.enabled}"
# Active session: dumpsys tv_input Connection for HW4 has non-null mCallingUid
HDMI3_ID="com.mediatek.tvinput/.hdmi.HDMIInputService/HW4"

in_work_window() {
  local dow hour min now
  dow="$(date +%u)"
  hour="$(date +%H)"
  min="$(date +%M)"
  now=$((10#$hour * 60 + 10#$min))
  [ "$dow" -le 5 ] && [ "$now" -ge 510 ] && [ "$now" -le 1110 ]
}

adb_online() {
  adb connect "$TV_ADB" >/dev/null 2>&1 || true
  adb devices 2>/dev/null | grep -qE "^${TV_ADB}[[:space:]]+device$"
}

webview_foreground() {
  adb -s "$TV_ADB" shell dumpsys window 2>/dev/null \
    | grep -qE 'mCurrentFocus=.*org\.chromium\.webview_shell'
}

on_hdmi3() {
  # HW4 block followed by numeric mCallingUid (active), not null
  adb -s "$TV_ADB" shell dumpsys tv_input 2>/dev/null \
    | grep -E "mCallingUid: [0-9]+" -B 6 \
    | grep -qF "$HDMI3_ID"
}

switch_hdmi3() {
  adb -s "$TV_ADB" shell am start -a com.mitv.tvhome.atv.app.tv.INPUTSOURCE_POPUP >/dev/null 2>&1 || true
  sleep 1
  adb -s "$TV_ADB" shell input tap 640 410 >/dev/null 2>&1 || true
}

[ -f "$AUTOFIX_FLAG" ] || exit 0
in_work_window || exit 0
adb_online || exit 0
webview_foreground && exit 0
on_hdmi3 && exit 0
switch_hdmi3
exit 0
