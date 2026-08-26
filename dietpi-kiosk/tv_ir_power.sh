#!/bin/bash
# Send IR Power to Xiaomi TV via 3.5mm jack — boosted ALSA path.
# Target: /root/tv_ir_power.sh

set -euo pipefail

IR_DIR="${IR_DIR:-/root/ir}"
WAV_FILE="${IR_DIR}/xiaomi_power.wav"
WAV_36="${IR_DIR}/xiaomi_power_36k.wav"
WAV_38="${IR_DIR}/xiaomi_power_38k.wav"
# Analog headphone (not HDMI)
IR_ALSA_DEVICE="${IR_ALSA_DEVICE:-plughw:0,0}"
REPEATS="${IR_REPEATS:-4}"

mkdir -p "$IR_DIR"
GEN="${IR_DIR}/generate-xiaomi-power-wav.py"

regen() {
  python3 "$GEN" "$WAV_38" 38000
  python3 "$GEN" "$WAV_36" 36000
  cp -f "$WAV_38" "$WAV_FILE"
}

if [ ! -x "$GEN" ] && [ -f "$GEN" ]; then
  chmod +x "$GEN" || true
fi

if [ ! -f "$WAV_38" ] || [ ! -f "$WAV_36" ] || [ "${IR_REGEN:-0}" = "1" ]; then
  if [ -f "$GEN" ]; then
    regen
  elif [ ! -f "$WAV_FILE" ]; then
    echo "ERROR: missing WAV and generator" >&2
    exit 1
  fi
fi

command -v aplay >/dev/null 2>&1 || {
  echo "ERROR: aplay not found" >&2
  exit 1
}

# Max analog output
amixer -c 0 sset Master unmute 100% 2>/dev/null || true
amixer -c 0 -- sset Master 87 2>/dev/null || true
# Softvol boost > 0 dB if present
amixer -c 0 sset IRBoost 100% 2>/dev/null || true

# Optional ALSA softvol wrapper (created once)
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

# Prefer softvol device if mixer exists after first open
PLAY_DEV="$IR_ALSA_DEVICE"
if amixer -c 0 sget IRBoost >/dev/null 2>&1; then
  amixer -c 0 sset IRBoost 100% 2>/dev/null || true
  PLAY_DEV="irboost"
fi

blast() {
  local wav="$1"
  local label="$2"
  echo "IR blast $label -> $PLAY_DEV ($wav)"
  local i=0
  while [ "$i" -lt "$REPEATS" ]; do
    aplay -D "$PLAY_DEV" -q "$wav" 2>/dev/null || aplay -D "$IR_ALSA_DEVICE" -q "$wav"
    i=$((i + 1))
    [ "$i" -lt "$REPEATS" ] && sleep 0.25
  done
}

# First play creates IRBoost control; retry softvol path
aplay -D irboost -q /dev/zero 2>/dev/null || true
if amixer -c 0 sget IRBoost >/dev/null 2>&1; then
  amixer -c 0 sset IRBoost 100% >/dev/null
  PLAY_DEV="irboost"
  echo "Using softvol IRBoost +20 dB max on $IR_ALSA_DEVICE"
fi

blast "${WAV_38:-$WAV_FILE}" "38 kHz"
blast "${WAV_36:-$WAV_FILE}" "36 kHz"

echo "IR Power blast done (boosted jack). LED must face TV IR window closely."
exit 0
