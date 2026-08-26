#!/bin/bash
# Turn Xiaomi TV off.
# Target: /root/tv_off.sh
#
# Soft: ADB sleep/shutdown when online.
# Optional: IR_POWER=1 also blasts USB IR Power (toggle) when blaster is ready.

set -euo pipefail

TV_ADB="${TV_ADB:-192.168.0.2:5555}"
IR_POWER="${IR_POWER:-0}"

if [ "$IR_POWER" = "1" ] && [ -x /root/tv_ir_power.sh ]; then
  echo "TV off: USB IR Power toggle"
  /root/tv_ir_power.sh || true
fi

if adb connect "$TV_ADB" >/dev/null 2>&1 \
  && adb devices 2>/dev/null | grep -qE "^${TV_ADB}[[:space:]]+device$"; then
  echo "TV off: ADB sleep/shutdown"
  adb shell input keyevent 223 || true
  adb shell am broadcast -a android.intent.action.REQUEST_SHUTDOWN || true
  echo "Done."
  exit 0
fi

echo "WARN: ADB offline — TV already down or unreachable" >&2
exit 0
