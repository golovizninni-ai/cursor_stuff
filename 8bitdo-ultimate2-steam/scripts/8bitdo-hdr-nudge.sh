#!/bin/bash
# После старта Game Mode: Force Composite + toggle HDR (выбеленная картинка).
#
# Известный quirk Steam/gamescope (Bazzite «Rainbow Display» / washed HDR при
# Desktop → Game Mode). Ручной фикс: QAM → HDR off → on; Developer → Force Composite.
#
# Автоматика: X11-атомы gamescope (тот же путь, что у Steam QAM):
#   GAMESCOPE_COMPOSITE_FORCE
#   GAMESCOPE_DISPLAY_HDR_ENABLED
#
# Запуск: post_gamescope_start (см. install-hdr-workaround.sh)
set -euo pipefail

LOG="${HOME}/.cache/8bitdo-hdr-nudge.log"
DELAY="${HDR_NUDGE_DELAY:-12}"
FORCE_COMPOSITE="${HDR_FORCE_COMPOSITE:-1}"
TOGGLE_HDR="${HDR_TOGGLE_NUDGE:-1}"
TOGGLE_GAP="${HDR_TOGGLE_GAP:-0.6}"

mkdir -p "$(dirname "$LOG")"

log() {
  echo "$(date -Iseconds) $*" | tee -a "$LOG" >&2
  logger -t 8bitdo-hdr-nudge -- "$*" 2>/dev/null || true
}

set_cardinal() {
  local atom="$1" value="$2"
  if ! command -v xprop >/dev/null 2>&1; then
    return 1
  fi
  # CARDINAL 32 — формат, который читает gamescope get_prop()
  xprop -root -f "$atom" 32c -set "$atom" "$value" 2>>"$LOG"
}

read_cardinal() {
  local atom="$1"
  xprop -root "$atom" 2>/dev/null | sed -n 's/.*[= ]\([0-9][0-9]*\).*/\1/p' | head -1
}

find_gamescope_display() {
  # post_gamescope_start уже экспортирует DISPLAY на Xwayland gamescope
  if [[ -n "${DISPLAY:-}" ]] && xprop -root >/dev/null 2>&1; then
    echo "$DISPLAY"
    return 0
  fi
  local d
  for d in :1 :0 :2 :3; do
    if DISPLAY="$d" xprop -root >/dev/null 2>&1; then
      echo "$d"
      return 0
    fi
  done
  return 1
}

log "start (delay=${DELAY}s force_composite=${FORCE_COMPOSITE} toggle_hdr=${TOGGLE_HDR})"

if ! pgrep -x gamescope >/dev/null 2>&1; then
  # сразу после post_gamescope_start процесс уже есть; если нет — подождём
  log "waiting for gamescope process..."
  for _ in $(seq 1 30); do
    pgrep -x gamescope >/dev/null 2>&1 && break
    sleep 0.5
  done
fi

if ! pgrep -x gamescope >/dev/null 2>&1; then
  log "gamescope not running — abort"
  exit 0
fi

if ! command -v xprop >/dev/null 2>&1; then
  log "xprop missing — поставьте xorg-x11-utils / xprop; пока только ручной HDR toggle"
  exit 0
fi

GS_DISPLAY="$(find_gamescope_display || true)"
if [[ -z "${GS_DISPLAY}" ]]; then
  log "no X display for gamescope — abort"
  exit 0
fi
export DISPLAY="$GS_DISPLAY"
log "using DISPLAY=$DISPLAY"

# Force Composite сразу (можно до Steam) — часто убирает washed/rainbow
if [[ "$FORCE_COMPOSITE" == "1" ]]; then
  if set_cardinal GAMESCOPE_COMPOSITE_FORCE 1; then
    log "set GAMESCOPE_COMPOSITE_FORCE=1"
  else
    log "failed to set GAMESCOPE_COMPOSITE_FORCE"
  fi
fi

log "waiting ${DELAY}s for Steam UI / HDR state..."
sleep "$DELAY"

if [[ "$TOGGLE_HDR" != "1" ]]; then
  log "HDR toggle disabled (HDR_TOGGLE_NUDGE=0) — done"
  exit 0
fi

# Ждём появления атома (Steam мог ещё не выставить)
for _ in $(seq 1 40); do
  cur="$(read_cardinal GAMESCOPE_DISPLAY_HDR_ENABLED || true)"
  if [[ -n "$cur" ]]; then
    log "GAMESCOPE_DISPLAY_HDR_ENABLED currently=$cur"
    break
  fi
  sleep 0.5
done

# off → on — тот же эффект, что QAM HDR toggle
if set_cardinal GAMESCOPE_DISPLAY_HDR_ENABLED 0; then
  log "HDR → 0"
else
  log "failed HDR → 0 (atom may appear after Steam starts)"
fi
sleep "$TOGGLE_GAP"

if set_cardinal GAMESCOPE_DISPLAY_HDR_ENABLED 1; then
  log "HDR → 1"
else
  log "failed HDR → 1"
fi

# повторно закрепить Force Composite на случай, если Steam его сбросил
if [[ "$FORCE_COMPOSITE" == "1" ]]; then
  set_cardinal GAMESCOPE_COMPOSITE_FORCE 1 || true
fi

log "done. Если всё ещё выбелено — вручную QAM HDR off/on; Steam → System → Developer mode → Force Composite"
exit 0
