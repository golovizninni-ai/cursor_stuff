#!/bin/bash
# Send IR Power to Xiaomi TV via 3.5mm jack (ALSA) — jack-only setup.
# Target: /root/tv_ir_power.sh
#
# Requires: IR emitter in headphone jack, aimed at TV IR window.
# WAV: /root/ir/xiaomi_power.wav (generate with generate-xiaomi-power-wav.py)

set -euo pipefail

IR_DIR="${IR_DIR:-/root/ir}"
WAV_FILE="${IR_DIR}/xiaomi_power.wav"
# Prefer analog headphone out, not HDMI
IR_ALSA_DEVICE="${IR_ALSA_DEVICE:-plughw:0,0}"
REPEATS="${IR_REPEATS:-2}"

if [ ! -f "$WAV_FILE" ]; then
  if [ -x "${IR_DIR}/generate-xiaomi-power-wav.py" ]; then
    python3 "${IR_DIR}/generate-xiaomi-power-wav.py" "$WAV_FILE"
  else
    echo "ERROR: missing $WAV_FILE — run generate-xiaomi-power-wav.py" >&2
    exit 1
  fi
fi

if ! command -v aplay >/dev/null 2>&1; then
  echo "ERROR: aplay not found (install alsa-utils)" >&2
  exit 1
fi

# Unmute / raise analog playback (ignore failures on missing controls)
amixer -c 0 sset Master unmute 100% 2>/dev/null || true
amixer -c 0 sset Speaker unmute 100% 2>/dev/null || true
amixer -c 0 sset Headphone unmute 100% 2>/dev/null || true
amixer -c 0 sset PCM unmute 100% 2>/dev/null || true

echo "IR Power via ALSA device ${IR_ALSA_DEVICE} ($WAV_FILE)"
i=0
while [ "$i" -lt "$REPEATS" ]; do
  aplay -D "$IR_ALSA_DEVICE" -q "$WAV_FILE"
  i=$((i + 1))
  [ "$i" -lt "$REPEATS" ] && sleep 0.4
done

echo "IR Power blast done (jack). Aim LED at TV IR receiver."
exit 0
