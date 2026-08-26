#!/bin/bash
# Live USB IR test: OFF (ADB) -> wait ADB dead -> IR ON only (no WOL) -> poll ADB
# Target: /root/test-ir-cycle.sh
#
# Requires USB IR + /root/ir/xiaomi_power.ir

set -euo pipefail

TV_ADB="${TV_ADB:-192.168.0.2:5555}"
WAIT_OFF_MIN="${WAIT_OFF_MIN:-15}"
ADB_DEAD_TIMEOUT="${ADB_DEAD_TIMEOUT:-60}"
ADB_UP_TIMEOUT="${ADB_UP_TIMEOUT:-90}"
ADB_POLL="${ADB_POLL:-3}"

adb_online() {
  adb disconnect >/dev/null 2>&1 || true
  timeout 3 adb connect "$TV_ADB" >/dev/null 2>&1 || true
  adb devices 2>/dev/null | grep -qE "^${TV_ADB}[[:space:]]+device$"
}

if [ ! -c /dev/lirc0 ] && [ ! -c /dev/lirc1 ]; then
  echo "FAIL: no /dev/lirc* — plug USB IR blaster first" >&2
  exit 1
fi
if [ ! -f /root/ir/xiaomi_power.ir ]; then
  echo "FAIL: missing /root/ir/xiaomi_power.ir — run /root/ir/capture-xiaomi-power.sh" >&2
  exit 1
fi

echo "=== 1/4 OFF — ADB sleep/shutdown ==="
/root/tv_off.sh

echo "=== 2/4 wait until ADB is dead ==="
sleep "$WAIT_OFF_MIN"
deadline=$((SECONDS + ADB_DEAD_TIMEOUT))
while adb_online; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "FAIL: ADB still online — cannot prove IR ON" >&2
    exit 1
  fi
  echo "  still online..."
  sleep "$ADB_POLL"
done
adb disconnect >/dev/null 2>&1 || true
echo "ADB dead."

echo "=== 3/4 ON — USB IR only (no WOL) ==="
/root/tv_ir_power.sh

echo "=== 4/4 poll ADB without WOL ==="
deadline=$((SECONDS + ADB_UP_TIMEOUT))
while [ "$SECONDS" -lt "$deadline" ]; do
  if adb_online; then
    echo "SUCCESS: ADB back without WOL — USB IR woke the TV."
    /root/tv_on.sh || true
    exit 0
  fi
  echo "  waiting for ADB..."
  sleep "$ADB_POLL"
done

echo "FAIL: ADB did not return — check IR aim / captured code" >&2
exit 1
