#!/bin/bash
# Capture Xiaomi TV KEY_POWER into /root/ir/xiaomi_power.ir
# Requires USB IR receiver (or transceiver) exposing /dev/lirc*
#
# Usage (on NUC, as root):
#   /root/ir/capture-xiaomi-power.sh
# Point the original Xiaomi remote at the IR receiver and press Power once.

set -euo pipefail

IR_DIR="${IR_DIR:-/root/ir}"
OUT="${IR_DIR}/xiaomi_power.ir"
mkdir -p "$IR_DIR"

if ! command -v ir-ctl >/dev/null 2>&1; then
  echo "Install v4l-utils: apt-get install -y v4l-utils"
  exit 1
fi

DEV=""
for d in /dev/lirc0 /dev/lirc1; do
  if [ -c "$d" ]; then
    DEV="$d"
    break
  fi
done

if [ -z "$DEV" ]; then
  echo "No /dev/lirc* found. Plug in a USB IR receiver/blaster and retry."
  echo "Audio-jack blasters do not create /dev/lirc* — capture needs a real IR RX."
  exit 1
fi

echo "Using $DEV"
echo "Press POWER on the Xiaomi remote once (within 15s)..."
# mode2-style one-shot receive into pulse file
timeout 15 ir-ctl -d "$DEV" --receive="$OUT" --mode2 || true

if [ ! -s "$OUT" ]; then
  echo "No signal captured. Check receiver orientation and retry."
  exit 1
fi

echo "Saved: $OUT"
echo "Test: ir-ctl -d $DEV --send=$OUT"
echo "Or:   /root/tv_ir_power.sh"
