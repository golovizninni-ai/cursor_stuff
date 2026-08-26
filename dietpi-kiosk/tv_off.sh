#!/bin/bash
# Turn Xiaomi TV off for IR power-on testing.
# Target: /root/tv_off.sh
#
# Default: jack IR Power (toggle).
# IR_ONLY=1 — do not send ADB sleep/shutdown (cleaner IR toggle test).

set -euo pipefail

TV_ADB="${TV_ADB:-192.168.0.2:5555}"
IR_ONLY="${IR_ONLY:-0}"

echo "TV off: blasting IR Power via jack (toggle)"
if [ -x /root/tv_ir_power.sh ]; then
  /root/tv_ir_power.sh || true
else
  echo "WARN: /root/tv_ir_power.sh missing" >&2
fi

if [ "$IR_ONLY" = "1" ]; then
  echo "IR_ONLY=1 — skipping ADB sleep/shutdown"
  echo "Done. Wait until ADB dies, then: /root/tv_ir_power.sh"
  exit 0
fi

# Soft backup if Android still answers
if adb connect "$TV_ADB" >/dev/null 2>&1 \
  && adb devices 2>/dev/null | grep -qE "^${TV_ADB}[[:space:]]+device$"; then
  echo "ADB still online — sending sleep/shutdown too"
  adb shell input keyevent 223 || true
  adb shell am broadcast -a android.intent.action.REQUEST_SHUTDOWN || true
fi

echo "Done. Wait ~5–10s, then: /root/tv_ir_power.sh   or   /root/tv_on.sh"
