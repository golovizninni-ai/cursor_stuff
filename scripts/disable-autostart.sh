#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

resolve_variant "${1:-}"
MODE="$(read_install_mode "$VARIANT")"

if [[ "$MODE" == "docker" ]]; then
  log "Docker: снимаю restart с контейнеров (стек не глушу)"
  docker update --restart=no \
    "$(docker_world_container "$VARIANT")" \
    "$(docker_auth_container "$VARIANT")" \
    "$(docker_db_container "$VARIANT")" 2>/dev/null || true
  log "глушить: scripts/stop.sh $VARIANT"
  log "вернуть автозапуск: scripts/enable-autostart.sh $VARIANT && scripts/start.sh"
  exit 0
fi

systemd_for_variant "$VARIANT"
sc disable "$(auth_unit "$VARIANT")" "$(world_unit "$VARIANT")" || true
log "автозапуск $VARIANT выключен (процессы могли остаться)"
log "глушить: scripts/stop.sh $VARIANT"
