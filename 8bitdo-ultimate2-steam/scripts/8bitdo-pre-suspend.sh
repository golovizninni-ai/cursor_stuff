#!/bin/bash
# Перед kernel suspend: дождаться idle-донгла 2dc8:6013 (геймпад на доке / выключен).
# MODE=wait  — ждать 6013 до TIMEOUT секунд (по умолчанию)
# MODE=delay — всегда спать SLEEP_DELAY секунд (классические «20 секунд на док»)
#
# Не шлёт HID power-off и не делает unbind — это не проверено на Ultimate 2.

set -euo pipefail

LIB="$(cd "$(dirname "$0")" && pwd)/8bitdo-common.sh"
if [[ -f /usr/local/lib/8bitdo-common.sh ]]; then
  LIB=/usr/local/lib/8bitdo-common.sh
fi
# shellcheck disable=SC1090
source "$LIB"
load_sleep_config

usb_quiet_settle() {
  if command -v udevadm >/dev/null 2>&1; then
    udevadm settle --timeout=5 || true
  fi
  sleep 1
}

wait_until_idle() {
  local deadline=$((SECONDS + TIMEOUT))
  while (( SECONDS < deadline )); do
    if 8bitdo_is_idle; then
      return 0
    fi
    sleep 0.25
  done
  8bitdo_is_idle
}

log "pre-suspend MODE=$MODE TIMEOUT=$TIMEOUT SLEEP_DELAY=$SLEEP_DELAY products=$(8bitdo_products | tr '\n' ',' | sed 's/,$//')"

if [[ "$MODE" == "delay" ]]; then
  log "delay ${SLEEP_DELAY}s before suspend"
  sleep "$SLEEP_DELAY"
  usb_quiet_settle
  if 8bitdo_is_idle; then
    mark_slept_idle
    log "after delay: idle (6013 or no dongle)"
  else
    mark_slept_active
    log "after delay: still active ($(8bitdo_products | tr '\n' ' ')) — dock-after-sleep may wake"
  fi
  exit 0
fi

if 8bitdo_is_idle; then
  usb_quiet_settle
  mark_slept_idle
  log "already idle, suspend immediately"
  exit 0
fi

log "controller active, waiting up to ${TIMEOUT}s for 6013 (put on dock / hold Home)"
if wait_until_idle; then
  usb_quiet_settle
  if 8bitdo_is_idle; then
    mark_slept_idle
    log "reached idle, allowing suspend"
    exit 0
  fi
fi

usb_quiet_settle
mark_slept_active
log "timeout: still active ($(8bitdo_products | tr '\n' ' ')) — suspend anyway; post-resume may re-sleep on 6013"
exit 0
