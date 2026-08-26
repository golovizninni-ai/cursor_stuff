#!/bin/bash
# Soft ADB healthcheck in work hours:
# - ADB offline → WOL + wait + wake + HDMI 3
# - ADB online but screen asleep → wake + HDMI 3
# Cron: every minute Mon–Fri 08:30–18:30. No logs. No cold IR.
# Target: /root/tv_healthcheck.sh

set -euo pipefail

TV_ADB="${TV_ADB:-192.168.0.2:5555}"
TV_MAC="${TV_MAC:-d4:5e:ec:f5:01:0d}"
TV_IFACE="${TV_IFACE:-eth0}"
AUTOFIX_FLAG="${AUTOFIX_FLAG:-/root/tv_autofix.enabled}"
ADB_WAIT_SEC="${ADB_WAIT_SEC:-45}"
ADB_POLL_SEC="${ADB_POLL_SEC:-5}"

in_work_window() {
  local dow hour min now
  dow="$(date +%u)"   # 1=Mon … 7=Sun
  hour="$(date +%H)"
  min="$(date +%M)"
  now=$((10#$hour * 60 + 10#$min))
  # Mon–Fri 08:30–18:30
  [ "$dow" -le 5 ] && [ "$now" -ge 510 ] && [ "$now" -le 1110 ]
}

adb_online() {
  adb connect "$TV_ADB" >/dev/null 2>&1 || true
  adb devices 2>/dev/null | grep -qE "^${TV_ADB}[[:space:]]+device$"
}

# Xiaomi standby: mWakefulness=Asleep/Dozing while ADB often still up
screen_awake() {
  adb -s "$TV_ADB" shell dumpsys power 2>/dev/null \
    | grep -qE 'mWakefulness=Awake'
}

switch_hdmi3() {
  adb -s "$TV_ADB" shell am start -a com.mitv.tvhome.atv.app.tv.INPUTSOURCE_POPUP >/dev/null 2>&1 || true
  sleep 1
  adb -s "$TV_ADB" shell input tap 640 410 >/dev/null 2>&1 || true
}

wake_and_hdmi() {
  adb -s "$TV_ADB" shell input keyevent 224 >/dev/null 2>&1 || true
  sleep 2
  switch_hdmi3
}

[ -f "$AUTOFIX_FLAG" ] || exit 0
in_work_window || exit 0

if adb_online; then
  screen_awake && exit 0
  wake_and_hdmi
  exit 0
fi

etherwake -i "$TV_IFACE" "$TV_MAC" >/dev/null 2>&1 || true

deadline=$((SECONDS + ADB_WAIT_SEC))
while [ "$SECONDS" -lt "$deadline" ]; do
  if adb_online; then
    wake_and_hdmi
    exit 0
  fi
  sleep "$ADB_POLL_SEC"
done

exit 0
