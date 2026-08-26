#!/bin/bash
# Send IR Power to Xiaomi TV (cold boot).
# Target: /root/tv_ir_power.sh
#
# Backends (first that works wins):
#   1) ir-ctl --send /root/ir/xiaomi_power.ir   (USB /dev/lirc*)
#   2) irsend xiaomi KEY_POWER                  (LIRC)
#   3) aplay /root/ir/xiaomi_power.wav          (experimental 3.5mm jack)
#
# Capture codes: see /root/ir/README.md or repo dietpi-kiosk/ir/

set -euo pipefail

IR_DIR="${IR_DIR:-/root/ir}"
RAW_FILE="${IR_DIR}/xiaomi_power.ir"
WAV_FILE="${IR_DIR}/xiaomi_power.wav"
LIRC_REMOTE="${LIRC_REMOTE:-xiaomi}"
LIRC_KEY="${LIRC_KEY:-KEY_POWER}"

sent=0

if command -v ir-ctl >/dev/null 2>&1 && [ -f "$RAW_FILE" ]; then
  for dev in /dev/lirc0 /dev/lirc1; do
    [ -c "$dev" ] || continue
    if ir-ctl -d "$dev" --send="$RAW_FILE"; then
      echo "IR Power sent via ir-ctl $dev ($RAW_FILE)"
      sent=1
      break
    fi
  done
fi

if [ "$sent" -eq 0 ] && command -v irsend >/dev/null 2>&1; then
  if irsend SEND_ONCE "$LIRC_REMOTE" "$LIRC_KEY" 2>/dev/null; then
    echo "IR Power sent via irsend $LIRC_REMOTE $LIRC_KEY"
    sent=1
  fi
fi

# Experimental: 3.5mm headphone IR blaster (ALC255 on this NUC = hw:0,0)
if [ "$sent" -eq 0 ] && [ -f "$WAV_FILE" ] && command -v aplay >/dev/null 2>&1; then
  if aplay -D "${IR_ALSA_DEVICE:-default}" -q "$WAV_FILE"; then
    echo "IR Power played via ALSA ($WAV_FILE) — experimental jack path"
    sent=1
  fi
fi

if [ "$sent" -eq 0 ]; then
  echo "WARN: no IR backend ready (need USB IR + $RAW_FILE, or LIRC, or $WAV_FILE for jack)" >&2
  echo "WARN: cold-off TV will not power on without IR Power / smart plug" >&2
  exit 1
fi

# Some TVs need a second Power pulse
sleep 1
if [ -f "$RAW_FILE" ] && command -v ir-ctl >/dev/null 2>&1; then
  for dev in /dev/lirc0 /dev/lirc1; do
    [ -c "$dev" ] || continue
    ir-ctl -d "$dev" --send="$RAW_FILE" || true
    break
  done
elif command -v irsend >/dev/null 2>&1; then
  irsend SEND_ONCE "$LIRC_REMOTE" "$LIRC_KEY" 2>/dev/null || true
elif [ -f "$WAV_FILE" ]; then
  aplay -D "${IR_ALSA_DEVICE:-default}" -q "$WAV_FILE" || true
fi

exit 0
