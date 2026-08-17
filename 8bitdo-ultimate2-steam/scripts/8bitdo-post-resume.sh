#!/bin/bash
# После resume: если уснули с живым геймпадом, а проснулись уже в idle 6013 —
# это постановка на док / Home-off, не снятие с дока. Снова уходим в сон.
#
# 6012 (D-Input) и 310b (XInput) — любое включение 8BitDo: остаёмся awake.
# Если уснули уже idle — не ре-suspend (wake от клавиатуры/питания/PCIe).

set -euo pipefail

LIB="$(cd "$(dirname "$0")" && pwd)/8bitdo-common.sh"
if [[ -f /usr/local/lib/8bitdo-common.sh ]]; then
  LIB=/usr/local/lib/8bitdo-common.sh
fi
# shellcheck disable=SC1090
source "$LIB"
load_sleep_config

schedule_resuspend() {
  local now last=0
  now="$(date +%s)"
  if [[ -f "$RESUSPEND_STAMP" ]]; then
    last="$(cat "$RESUSPEND_STAMP" 2>/dev/null || echo 0)"
  fi
  if (( now - last < 15 )); then
    log "skip re-suspend, debounce"
    return 0
  fi
  echo "$now" >"$RESUSPEND_STAMP"
  log "scheduling suspend in ${RESUSPEND_DELAY}s (dock/Home-off wake)"
  if command -v systemd-run >/dev/null 2>&1; then
    systemctl stop 8bitdo-resuspend.service 8bitdo-resuspend.timer 2>/dev/null || true
    systemctl reset-failed 8bitdo-resuspend.service 8bitdo-resuspend.timer 2>/dev/null || true
    systemd-run --unit=8bitdo-resuspend --collect --quiet \
      --on-active="${RESUSPEND_DELAY}s" \
      /usr/bin/systemctl suspend || true
  else
    (sleep "$RESUSPEND_DELAY"; systemctl suspend) >/dev/null 2>&1 &
  fi
}

log "post-resume products=$(8bitdo_products | tr '\n' ',' | sed 's/,$//') idle_flag=$([[ -f $FLAG_IDLE ]] && echo 1 || echo 0) active_flag=$([[ -f $FLAG_ACTIVE ]] && echo 1 || echo 0)"

if 8bitdo_is_controller_on; then
  log "controller on (D-Input or XInput) — stay awake"
  clear_sleep_flags
  exit 0
fi

if [[ -f "$FLAG_ACTIVE" ]] && 8bitdo_is_idle; then
  schedule_resuspend
  exit 0
fi

log "stay awake (slept idle, or no matching 8BitDo state)"
exit 0
