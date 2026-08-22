#!/bin/bash
# После старта Game Mode: авто toggle HDR (выбеленная картинка).
#
# У тебя надёжный ручной фикс = QAM → HDR off → on (100%).
# Force Composite / «Принудительная компоновка» этот эффект НЕ даёт — по умолчанию
# его не трогаем (HDR_FORCE_COMPOSITE=0).
#
# Автоматика: X11-атом gamescope (тот же путь, что у Steam QAM):
#   GAMESCOPE_DISPLAY_HDR_ENABLED  1→0→1
#
# Запуск: post_gamescope_start (см. install-hdr-workaround.sh)
set -euo pipefail

LOG="${HOME}/.cache/8bitdo-hdr-nudge.log"
DELAY="${HDR_NUDGE_DELAY:-15}"
FORCE_COMPOSITE="${HDR_FORCE_COMPOSITE:-0}"
TOGGLE_HDR="${HDR_TOGGLE_NUDGE:-1}"
TOGGLE_GAP="${HDR_TOGGLE_GAP:-1.0}"
# второй проход (Steam иногда перезаписывает атом после первого toggle)
SECOND_PASS_DELAY="${HDR_NUDGE_SECOND_DELAY:-8}"
PASSES="${HDR_NUDGE_PASSES:-2}"

mkdir -p "$(dirname "$LOG")"

log() {
  echo "$(date -Iseconds) $*" | tee -a "$LOG" >&2
  logger -t 8bitdo-hdr-nudge -- "$*" 2>/dev/null || true
}

set_cardinal() {
  local atom="$1" value="$2"
  command -v xprop >/dev/null 2>&1 || return 1
  # CARDINAL 32 — формат, который читает gamescope get_prop()
  xprop -root -f "$atom" 32c -set "$atom" "$value" 2>>"$LOG"
}

read_cardinal() {
  local atom="$1"
  xprop -root "$atom" 2>/dev/null | sed -n 's/.*[= ]\([0-9][0-9]*\).*/\1/p' | head -1
}

find_gamescope_display() {
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

wait_for_steam() {
  local i
  for i in $(seq 1 60); do
    if pgrep -f 'steamwebhelper|steam\.sh|bin/steam' >/dev/null 2>&1; then
      log "steam process detected"
      return 0
    fi
    sleep 0.5
  done
  log "steam process not seen yet — continue anyway"
  return 0
}

wait_hdr_atom() {
  # Ждём, пока Steam/gamescope выставит атом (желательно уже =1)
  local i cur
  for i in $(seq 1 60); do
    cur="$(read_cardinal GAMESCOPE_DISPLAY_HDR_ENABLED || true)"
    if [[ -n "$cur" ]]; then
      log "GAMESCOPE_DISPLAY_HDR_ENABLED=$cur"
      return 0
    fi
    sleep 0.5
  done
  log "HDR atom not present yet — will still try set"
  return 0
}

hdr_toggle_once() {
  local pass="$1"
  log "HDR toggle pass #$pass (off → on, gap=${TOGGLE_GAP}s)"

  if set_cardinal GAMESCOPE_DISPLAY_HDR_ENABLED 0; then
    log "  HDR → 0  (now=$(read_cardinal GAMESCOPE_DISPLAY_HDR_ENABLED || echo '?'))"
  else
    log "  failed HDR → 0"
    return 1
  fi
  sleep "$TOGGLE_GAP"

  if set_cardinal GAMESCOPE_DISPLAY_HDR_ENABLED 1; then
    log "  HDR → 1  (now=$(read_cardinal GAMESCOPE_DISPLAY_HDR_ENABLED || echo '?'))"
  else
    log "  failed HDR → 1"
    return 1
  fi
  return 0
}

log "start (delay=${DELAY}s force_composite=${FORCE_COMPOSITE} toggle_hdr=${TOGGLE_HDR} passes=${PASSES})"

if ! pgrep -x gamescope >/dev/null 2>&1; then
  log "waiting for gamescope..."
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
  log "xprop missing — нужен пакет с xprop; пока только ручной HDR toggle в QAM"
  exit 0
fi

GS_DISPLAY="$(find_gamescope_display || true)"
if [[ -z "${GS_DISPLAY}" ]]; then
  log "no X display for gamescope — abort"
  exit 0
fi
export DISPLAY="$GS_DISPLAY"
log "using DISPLAY=$DISPLAY"

if [[ "$FORCE_COMPOSITE" == "1" ]]; then
  if set_cardinal GAMESCOPE_COMPOSITE_FORCE 1; then
    log "set GAMESCOPE_COMPOSITE_FORCE=1 (optional; обычно не чинит выбеливание)"
  else
    log "failed GAMESCOPE_COMPOSITE_FORCE"
  fi
fi

if [[ "$TOGGLE_HDR" != "1" ]]; then
  log "HDR toggle disabled (HDR_TOGGLE_NUDGE=0) — done"
  exit 0
fi

wait_for_steam
log "waiting ${DELAY}s for Steam UI / HDR to settle..."
sleep "$DELAY"
wait_hdr_atom

# Если HDR уже выключен (атом=0) — просто включим; иначе off→on
cur="$(read_cardinal GAMESCOPE_DISPLAY_HDR_ENABLED || true)"
if [[ "$cur" == "0" ]]; then
  log "HDR was 0 — enabling once"
  set_cardinal GAMESCOPE_DISPLAY_HDR_ENABLED 1 || true
  sleep "$TOGGLE_GAP"
fi

pass=1
while [[ "$pass" -le "$PASSES" ]]; do
  hdr_toggle_once "$pass" || true
  if [[ "$pass" -lt "$PASSES" ]]; then
    log "waiting ${SECOND_PASS_DELAY}s before pass $((pass + 1))..."
    sleep "$SECOND_PASS_DELAY"
  fi
  pass=$((pass + 1))
done

log "done. Если всё ещё выбелено — вручную QAM: Display → HDR выкл → вкл"
exit 0
