#!/bin/bash
# Ensure Xiaomi TV stays on HDMI 3 (MediaTek HW4).
# Cron: every 5 min Mon–Fri 08:30–18:30. No logs.
# Target: /root/tv_hdmi_watchdog.sh

set -euo pipefail

export PATH="/usr/sbin:/usr/bin:/bin:${PATH:-}"

TV_ADB="${TV_ADB:-192.168.0.2:5555}"
AUTOFIX_FLAG="${AUTOFIX_FLAG:-/root/tv_autofix.enabled}"
LOCK_FILE="${LOCK_FILE:-/run/tv_hdmi_watchdog.lock}"
DUMP_TIMEOUT="${DUMP_TIMEOUT:-4}"
# Active session: dumpsys tv_input Connection for HW4 has non-null mCallingUid
HDMI3_ID="com.mediatek.tvinput/.hdmi.HDMIInputService/HW4"

exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

in_work_window() {
  local dow hour min now
  dow="$(date +%u)"
  hour="$(date +%H)"
  min="$(date +%M)"
  now=$((10#$hour * 60 + 10#$min))
  [ "$dow" -le 5 ] && [ "$now" -ge 510 ] && [ "$now" -le 1110 ]
}

adb_online() {
  timeout 5 adb connect "$TV_ADB" >/dev/null 2>&1 || true
  timeout 5 adb devices 2>/dev/null | grep -qE "^${TV_ADB}[[:space:]]+device$"
}

# dumpsys can hang in sleep — fail closed (skip HDMI fix; healthcheck wakes)
webview_foreground() {
  local out
  out="$(timeout "$DUMP_TIMEOUT" adb -s "$TV_ADB" shell dumpsys window 2>/dev/null || true)"
  [ -n "$out" ] || return 1
  echo "$out" | grep -qE 'mCurrentFocus=.*org\.chromium\.webview_shell'
}

on_hdmi3() {
  local out
  out="$(timeout "$DUMP_TIMEOUT" adb -s "$TV_ADB" shell dumpsys tv_input 2>/dev/null || true)"
  [ -n "$out" ] || return 1
  echo "$out" | grep -E "mCallingUid: [0-9]+" -B 6 | grep -qF "$HDMI3_ID"
}

switch_hdmi3() {
  timeout 8 adb -s "$TV_ADB" shell am start -a com.mitv.tvhome.atv.app.tv.INPUTSOURCE_POPUP >/dev/null 2>&1 || true
  sleep 1
  timeout 5 adb -s "$TV_ADB" shell input tap 640 410 >/dev/null 2>&1 || true
}

[ -f "$AUTOFIX_FLAG" ] || exit 0
in_work_window || exit 0
adb_online || exit 0
webview_foreground && exit 0
on_hdmi3 && exit 0
switch_hdmi3
exit 0
