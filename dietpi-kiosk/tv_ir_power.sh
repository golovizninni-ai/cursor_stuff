#!/bin/bash
# Send IR Power via 3.5mm jack (ALSA).
# Target: /root/tv_ir_power.sh
#
# IMPORTANT (this NUC / ALC255 Analog hw:0,0):
#   Hardware max sample rate is 48000 Hz. Nyquist = 24 kHz.
#   Classic IR needs a ~36–38 kHz optical carrier, which CANNOT be
#   reproduced on this headphone jack. Boosting volume does not help.
#   Use a USB IR blaster or a smart plug for cold power-on.

set -euo pipefail

IR_DIR="${IR_DIR:-/root/ir}"
WAV_FILE="${IR_DIR}/xiaomi_power.wav"
WAV_36="${IR_DIR}/xiaomi_power_36k.wav"
WAV_38="${IR_DIR}/xiaomi_power_38k.wav"
IR_ALSA_DEVICE="${IR_ALSA_DEVICE:-plughw:0,0}"
REPEATS="${IR_REPEATS:-4}"

mkdir -p "$IR_DIR"
GEN="${IR_DIR}/generate-xiaomi-power-wav.py"

if [ -f "$GEN" ] && { [ ! -f "$WAV_38" ] || [ "${IR_REGEN:-0}" = "1" ]; }; then
  python3 "$GEN" "$WAV_38" 38000
  python3 "$GEN" "$WAV_36" 36000
  cp -f "$WAV_38" "$WAV_FILE"
fi

if [ ! -f "$WAV_FILE" ]; then
  echo "ERROR: missing $WAV_FILE" >&2
  exit 1
fi

command -v aplay >/dev/null 2>&1 || {
  echo "ERROR: aplay not found" >&2
  exit 1
}

# Warn once about hardware limit
echo "WARN: ALC255 Analog is capped at 48 kHz — 38 kHz IR carrier cannot pass this jack." >&2
echo "WARN: Blast is experimental; expect no TV response. Prefer USB IR or smart plug." >&2

amixer -c 0 sset Master unmute 100% 2>/dev/null || true

ASOUND="/root/.asoundrc"
if [ ! -f "$ASOUND" ] || ! grep -q 'pcm.irboost' "$ASOUND" 2>/dev/null; then
  cat > "$ASOUND" << 'EOF'
pcm.irboost {
  type softvol
  slave.pcm "plughw:0,0"
  control {
    name "IRBoost"
    card 0
  }
  min_dB -10.0
  max_dB 20.0
  resolution 100
}
EOF
fi

PLAY_DEV="$IR_ALSA_DEVICE"
# Open once to register softvol, then max boost
aplay -D irboost -q -d 1 /dev/zero 2>/dev/null || true
if amixer -c 0 sget IRBoost >/dev/null 2>&1; then
  amixer -c 0 sset IRBoost 100% >/dev/null
  PLAY_DEV="irboost"
  echo "Using softvol IRBoost (~+20 dB) on $IR_ALSA_DEVICE"
fi

blast() {
  local wav="$1"
  local label="$2"
  [ -f "$wav" ] || return 0
  echo "IR blast $label -> $PLAY_DEV"
  local i=0
  while [ "$i" -lt "$REPEATS" ]; do
    aplay -D "$PLAY_DEV" -q "$wav" 2>/dev/null || aplay -D "$IR_ALSA_DEVICE" -q "$wav"
    i=$((i + 1))
    [ "$i" -lt "$REPEATS" ] && sleep 0.25
  done
}

blast "${WAV_38:-$WAV_FILE}" "38 kHz (will be downsampled to 48 kHz by HW)"
blast "${WAV_36:-$WAV_FILE}" "36 kHz (will be downsampled to 48 kHz by HW)"

echo "IR jack blast finished (signal boosted, but carrier likely destroyed by 48 kHz DAC)."
exit 0
