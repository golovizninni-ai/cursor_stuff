#!/bin/bash
# Soft ADB healthcheck in work hours:
# - ADB offline or screen not awake → /root/tv_on.sh (same path as web button)
# Cron: every minute Mon–Fri 08:30–18:30. No logs.
# Target: /root/tv_healthcheck.sh

set -euo pipefail

export PATH="/usr/sbin:/usr/bin:/bin:${PATH:-}"

TV_ADB="${TV_ADB:-192.168.0.2:5555}"
AUTOFIX_FLAG="${AUTOFIX_FLAG:-/root/tv_autofix.enabled}"
LOCK_FILE="${LOCK_FILE:-/run/tv_healthcheck.lock}"
DUMP_TIMEOUT="${DUMP_TIMEOUT:-4}"

# Single instance (cron overlap / hung dumpsys)
exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

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
  timeout 5 adb connect "$TV_ADB" >/dev/null 2>&1 || true
  timeout 5 adb devices 2>/dev/null | grep -qE "^${TV_ADB}[[:space:]]+device$"
}

# dumpsys power often HANGS while Xiaomi is in sleep — always use timeout.
# Timeout / Asleep / Dozing / Display OFF → not awake.
screen_awake() {
  local out
  out="$(timeout "$DUMP_TIMEOUT" adb -s "$TV_ADB" shell dumpsys power 2>/dev/null || true)"
  [ -n "$out" ] || return 1
  echo "$out" | grep -qE 'mWakefulness=Awake' || return 1
  echo "$out" | grep -qE 'Display Power: state=ON' || return 1
  return 0
}

[ -f "$AUTOFIX_FLAG" ] || exit 0
in_work_window || exit 0

if adb_online && screen_awake; then
  exit 0
fi

# Reuse working soft/cold path (WOL + IR hook + wake + HDMI 3)
timeout 150 /root/tv_on.sh >/dev/null 2>&1 || true
exit 0
