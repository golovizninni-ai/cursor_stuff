#!/bin/bash
# Следит за новым процессом gamescope и один раз за PID делает HDR toggle.
# Перекрывает: boot в Game Mode, Desktop→Game Mode, hotkey Monitor/TV.
set -euo pipefail

LOG="${HOME}/.cache/8bitdo-hdr-nudge.log"
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/8bitdo-hdr-nudge"
NUDGE="${HOME}/.local/bin/8bitdo-hdr-nudge.sh"
[[ -x /usr/local/bin/8bitdo-hdr-nudge.sh ]] && NUDGE=/usr/local/bin/8bitdo-hdr-nudge.sh

DELAY="${HDR_NUDGE_DELAY:-18}"
POLL="${HDR_NUDGE_POLL:-2}"

mkdir -p "$(dirname "$LOG")" "$STATE_DIR"

log() {
  echo "$(date -Iseconds) daemon: $*" | tee -a "$LOG" >&2
  logger -t 8bitdo-hdr-nudge -- "daemon: $*" 2>/dev/null || true
}

load_env() {
  local f
  for f in /etc/environment.d/*.conf "${HOME}"/.config/environment.d/*.conf; do
    [[ -f "$f" ]] || continue
    # shellcheck disable=SC1090
    set -a
    # только наши HDR_* чтобы не сломать shell
    while IFS='=' read -r k v; do
      [[ "$k" =~ ^HDR_ ]] || continue
      export "$k=$v"
    done < <(grep -E '^HDR_[A-Z0-9_]+=' "$f" 2>/dev/null || true)
    set +a
  done
  DELAY="${HDR_NUDGE_DELAY:-$DELAY}"
}

if [[ "${HDR_NUDGE:-1}" == "0" ]]; then
  log "HDR_NUDGE=0 — exit"
  exit 0
fi

load_env
log "started (delay=${DELAY}s poll=${POLL}s nudge=$NUDGE)"

LAST_HANDLED=""
while true; do
  load_env
  if [[ "${HDR_NUDGE:-1}" == "0" ]]; then
    sleep "$POLL"
    continue
  fi

  # основной pid gamescope (первый)
  PID="$(pgrep -x gamescope 2>/dev/null | head -n1 || true)"
  if [[ -z "$PID" ]]; then
    LAST_HANDLED=""
    sleep "$POLL"
    continue
  fi

  if [[ "$PID" == "$LAST_HANDLED" ]]; then
    sleep "$POLL"
    continue
  fi

  # новый gamescope — ждём Steam/HDR settle
  log "new gamescope pid=$PID — wait ${DELAY}s"
  # если pid исчез за время ожидания — сброс
  slept=0
  while [[ "$slept" -lt "$DELAY" ]]; do
    if ! kill -0 "$PID" 2>/dev/null; then
      log "gamescope $PID gone during wait"
      break
    fi
    sleep 1
    slept=$((slept + 1))
  done

  if ! kill -0 "$PID" 2>/dev/null; then
    LAST_HANDLED=""
    continue
  fi

  # дополнительная пауза пока появится steam
  for _ in $(seq 1 30); do
    pgrep -f 'steamwebhelper|bin/steam' >/dev/null 2>&1 && break
    sleep 0.5
  done

  log "nudging for gamescope pid=$PID"
  if [[ -x "$NUDGE" ]]; then
    # one-shot (без --daemon)
    "$NUDGE" >>"$LOG" 2>&1 || log "nudge exit $?"
  else
    log "ERROR: nudge script missing: $NUDGE"
  fi

  LAST_HANDLED="$PID"
  echo "$PID" >"${STATE_DIR}/last-pid"
  sleep "$POLL"
done
