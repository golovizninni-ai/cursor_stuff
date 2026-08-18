#!/usr/bin/env bash
# Сначала world (сейв), потом auth. Docker или systemd — по install-mode.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

resolve_variant "${1:-}"
MODE="$(read_install_mode "$VARIANT")"

if [[ "$MODE" == "docker" ]]; then
  log "стоп docker world ($VARIANT)"
  dc stop ac-worldserver || true
  log "стоп docker auth"
  dc stop ac-authserver || true
  log "сервер $VARIANT выключен (БД контейнер жив)"
  dc ps || true
  exit 0
fi

systemd_for_variant "$VARIANT"
log "стоп world ($VARIANT), ждём сейв до 90с — не kill -9"
sc stop "$(world_unit "$VARIANT")" || true
log "стоп auth"
sc stop "$(auth_unit "$VARIANT")" || true

if pgrep -x worldserver >/dev/null 2>&1 || pgrep -x authserver >/dev/null 2>&1; then
  log "остались процессы — мягкий TERM"
  pkill -TERM -x worldserver 2>/dev/null || true
  sleep 3
  pkill -TERM -x authserver 2>/dev/null || true
fi

log "сервер $VARIANT выключен"
sc --no-pager --full status "$(auth_unit "$VARIANT")" "$(world_unit "$VARIANT")" || true
