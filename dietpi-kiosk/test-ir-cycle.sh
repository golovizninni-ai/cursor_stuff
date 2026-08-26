#!/bin/bash
# Live test: prove TV turns ON from jack IR alone (no WOL, no ADB wake).
# Target: /root/test-ir-cycle.sh
#
# Flow:
#   1) IR Power OFF (toggle), no ADB sleep
#   2) wait until ADB is dead
#   3) IR Power ON only
#   4) poll ADB without etherwake — if it comes up, IR did the work

set -euo pipefail

TV_ADB="${TV_ADB:-192.168.0.2:5555}"
WAIT_OFF_MIN="${WAIT_OFF_MIN:-15}"
ADB_DEAD_TIMEOUT="${ADB_DEAD_TIMEOUT:-60}"
ADB_UP_TIMEOUT="${ADB_UP_TIMEOUT:-90}"
ADB_POLL="${ADB_POLL:-3}"

adb_online() {
  adb disconnect >/dev/null 2>&1 || true
  # do not keep retrying forever — one short connect attempt
  timeout 3 adb connect "$TV_ADB" >/dev/null 2>&1 || true
  adb devices 2>/dev/null | grep -qE "^${TV_ADB}[[:space:]]+device$"
}

echo "=== 1/4 OFF — jack IR Power only (no ADB shutdown) ==="
IR_ONLY=1 /root/tv_off.sh

echo "=== 2/4 wait until ADB is dead (min ${WAIT_OFF_MIN}s, max ${ADB_DEAD_TIMEOUT}s) ==="
sleep "$WAIT_OFF_MIN"
deadline=$((SECONDS + ADB_DEAD_TIMEOUT))
while adb_online; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "FAIL: ADB still online — TV not really off; IR ON test would be inconclusive" >&2
    exit 1
  fi
  echo "  still online, waiting..."
  sleep "$ADB_POLL"
done
adb disconnect >/dev/null 2>&1 || true
echo "ADB dead. Good — TV looks off/network down."

echo "=== 3/4 ON — jack IR ONLY (no WOL, no etherwake, no tv_on.sh) ==="
/root/tv_ir_power.sh

echo "=== 4/4 poll ADB without WOL (up to ${ADB_UP_TIMEOUT}s) ==="
deadline=$((SECONDS + ADB_UP_TIMEOUT))
while [ "$SECONDS" -lt "$deadline" ]; do
  if adb_online; then
    echo "SUCCESS: ADB came back without WOL — IR Power likely woke the TV."
    echo "Optional HDMI switch: adb shell am start ... (or /root/tv_on.sh soft path)"
    # soft HDMI only if already up — tv_on will take soft path
    /root/tv_on.sh || true
    exit 0
  fi
  echo "  waiting for ADB..."
  sleep "$ADB_POLL"
done

echo "FAIL: ADB did not return. IR ON probably did not wake TV (wrong code / LED aim / volume)." >&2
echo "Note: if you run /root/tv_on.sh now, WOL may still wake standby — that is NOT an IR proof." >&2
exit 1
