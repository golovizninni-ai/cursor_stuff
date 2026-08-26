#!/bin/bash
# Send IR Power to Xiaomi TV via USB IR blaster.
# Target: /root/tv_ir_power.sh
#
# Hooks (first that works):
#   1) ir-ctl --send /root/ir/xiaomi_power.ir   (/dev/lirc*)
#   2) irsend xiaomi KEY_POWER                  (LIRC)
#
# Capture code after plugging USB IR RX/TX:
#   /root/ir/capture-xiaomi-power.sh

set -euo pipefail

IR_DIR="${IR_DIR:-/root/ir}"
RAW_FILE="${IR_DIR}/xiaomi_power.ir"
LIRC_REMOTE="${LIRC_REMOTE:-xiaomi}"
LIRC_KEY="${LIRC_KEY:-KEY_POWER}"

sent=0

if command -v ir-ctl >/dev/null 2>&1 && [ -f "$RAW_FILE" ]; then
  for dev in /dev/lirc0 /dev/lirc1; do
    [ -c "$dev" ] || continue
    if ir-ctl -d "$dev" --send="$RAW_FILE"; then
      echo "IR Power sent via ir-ctl $dev ($RAW_FILE)"
      sent=1
      sleep 0.5
      ir-ctl -d "$dev" --send="$RAW_FILE" || true
      break
    fi
  done
fi

if [ "$sent" -eq 0 ] && command -v irsend >/dev/null 2>&1; then
  if irsend SEND_ONCE "$LIRC_REMOTE" "$LIRC_KEY" 2>/dev/null; then
    echo "IR Power sent via irsend $LIRC_REMOTE $LIRC_KEY"
    sent=1
    sleep 0.5
    irsend SEND_ONCE "$LIRC_REMOTE" "$LIRC_KEY" 2>/dev/null || true
  fi
fi

if [ "$sent" -eq 0 ]; then
  echo "WARN: USB IR not ready — need /dev/lirc* + $RAW_FILE (or LIRC KEY_POWER)" >&2
  echo "WARN: plug USB IR blaster, then: /root/ir/capture-xiaomi-power.sh" >&2
  exit 1
fi

exit 0
