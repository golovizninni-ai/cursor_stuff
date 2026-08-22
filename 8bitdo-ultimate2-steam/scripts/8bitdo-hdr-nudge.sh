#!/bin/bash
# Один проход HDR off→on на Xwayland gamescope.
# DISPLAY/XAUTHORITY берутся из /proc/<gamescope>/environ — так надёжнее,
# чем post_gamescope_start (на части Bazzite hook не вызывается).
set -euo pipefail

LOG="${HOME}/.cache/8bitdo-hdr-nudge.log"
ROOT_BIN="$(cd "$(dirname "$0")" && pwd)"
TOGGLE_PY="${ROOT_BIN}/8bitdo-hdr-toggle.py"
[[ -x /usr/local/bin/8bitdo-hdr-toggle.py ]] && TOGGLE_PY=/usr/local/bin/8bitdo-hdr-toggle.py
[[ -x "${HOME}/.local/bin/8bitdo-hdr-toggle.py" ]] && TOGGLE_PY="${HOME}/.local/bin/8bitdo-hdr-toggle.py"

GAP="${HDR_TOGGLE_GAP:-2.0}"
PASSES="${HDR_NUDGE_PASSES:-2}"
SECOND="${HDR_NUDGE_SECOND_DELAY:-6}"

mkdir -p "$(dirname "$LOG")"

log() {
  echo "$(date -Iseconds) $*" | tee -a "$LOG" >&2
  logger -t 8bitdo-hdr-nudge -- "$*" 2>/dev/null || true
}

gamescope_pids() {
  pgrep -x gamescope 2>/dev/null || true
}

read_environ() {
  # read_environ PID KEY → value
  local pid="$1" key="$2" line
  [[ -r "/proc/$pid/environ" ]] || return 1
  while IFS= read -r -d '' line; do
    if [[ "$line" == "${key}="* ]]; then
      printf '%s\n' "${line#*=}"
      return 0
    fi
  done <"/proc/$pid/environ"
  return 1
}

pick_gamescope_env() {
  local pid dpy
  for pid in $(gamescope_pids); do
    dpy="$(read_environ "$pid" DISPLAY || true)"
    if [[ -n "$dpy" ]]; then
      export DISPLAY="$dpy"
      XAUTH="$(read_environ "$pid" XAUTHORITY || true)"
      if [[ -n "$XAUTH" ]]; then
        export XAUTHORITY="$XAUTH"
      fi
      # иногда нужен HOME пользователя сессии
      log "gamescope pid=$pid DISPLAY=$DISPLAY XAUTHORITY=${XAUTHORITY:-<unset>}"
      return 0
    fi
  done
  return 1
}

do_toggle() {
  export HDR_TOGGLE_GAP="$GAP"
  export HDR_NUDGE_PASSES="$PASSES"
  export HDR_NUDGE_SECOND_DELAY="$SECOND"

  if [[ -f "$TOGGLE_PY" ]]; then
    log "toggle via python: $TOGGLE_PY"
    if python3 "$TOGGLE_PY" >>"$LOG" 2>&1; then
      log "python toggle OK"
      return 0
    fi
    log "python toggle failed — try xprop"
  fi

  if ! command -v xprop >/dev/null 2>&1; then
    log "ERROR: нет ни python-toggle, ни xprop"
    return 1
  fi

  local p
  for p in $(seq 1 "$PASSES"); do
    log "xprop pass $p: HDR 0"
    xprop -root -f GAMESCOPE_DISPLAY_HDR_ENABLED 32c -set GAMESCOPE_DISPLAY_HDR_ENABLED 0 >>"$LOG" 2>&1 || true
    sleep "$GAP"
    log "xprop pass $p: HDR 1"
    xprop -root -f GAMESCOPE_DISPLAY_HDR_ENABLED 32c -set GAMESCOPE_DISPLAY_HDR_ENABLED 1 >>"$LOG" 2>&1 || true
    if [[ "$p" -lt "$PASSES" ]]; then
      sleep "$SECOND"
    fi
  done
  log "xprop toggle done (current=$(xprop -root GAMESCOPE_DISPLAY_HDR_ENABLED 2>/dev/null | tr -d '\n'))"
}

# --- main (one-shot) ---
if [[ "${1:-}" == "--daemon" ]]; then
  exec bash "$(dirname "$0")/8bitdo-hdr-nudge-daemon.sh"
fi

log "one-shot start"
if ! gamescope_pids | grep -q .; then
  log "gamescope not running"
  exit 0
fi
if ! pick_gamescope_env; then
  log "could not read DISPLAY from gamescope environ — trying \$DISPLAY=${DISPLAY:-unset}"
fi
do_toggle
log "one-shot done"
exit 0
