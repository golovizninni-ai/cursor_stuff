#!/bin/bash
# Live IR jack test: OFF -> wait -> ON (cold-ish cycle)
# Target: /root/test-ir-cycle.sh

set -euo pipefail

WAIT_OFF="${WAIT_OFF:-8}"
WAIT_BOOT="${WAIT_BOOT:-45}"

echo "=== 1/3 OFF (IR Power toggle) ==="
/root/tv_off.sh
echo "Waiting ${WAIT_OFF}s with TV off..."
sleep "$WAIT_OFF"

echo "=== 2/3 ON (IR Power via jack) ==="
/root/tv_ir_power.sh

echo "=== 3/3 wait ADB / HDMI ==="
ADB_WAIT_SEC="${WAIT_BOOT}" /root/tv_on.sh || true

echo "Cycle finished. Check TV screen (should be on HDMI 3 / kiosk)."
