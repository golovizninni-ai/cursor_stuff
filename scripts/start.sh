#!/usr/bin/env bash
# Запуск выбранного варианта. Native = systemd, Docker = compose.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

resolve_variant "${1:-}"
MODE="$(read_install_mode "$VARIANT")"
stop_other_variants "$VARIANT"

if [[ "$MODE" == "docker" ]]; then
  [[ -f "$SRC/docker-compose.yml" ]] || die "нет docker-compose.yml — переустановите scripts/install-docker.sh $VARIANT"
  log "старт docker $VARIANT (проект $(compose_project "$VARIANT"))"
  dc up -d
  write_active_variant "$VARIANT"
  "$SCRIPT_DIR/status.sh" "$VARIANT"
  log "консоль мира: docker attach $(docker_world_container "$VARIANT")  (Ctrl+P Ctrl+Q)"
  log "глушить: scripts/stop.sh"
  exit 0
fi

systemd_for_variant "$VARIANT"

if sc is-active --quiet "$(world_unit "$VARIANT")" 2>/dev/null; then
  log "уже запущен $VARIANT"
  exec "$SCRIPT_DIR/status.sh" "$VARIANT"
fi

if pgrep -x worldserver >/dev/null 2>&1 || pgrep -x authserver >/dev/null 2>&1; then
  die "authserver/worldserver крутятся не через systemd (tmux?). Остановите консоль или: scripts/stop.sh"
fi

$SUDO systemctl start mysql 2>/dev/null || $SUDO systemctl start mysqld 2>/dev/null || true

log "старт auth ($VARIANT)"
sc start "$(auth_unit "$VARIANT")"
sleep 1
log "старт world ($VARIANT)"
sc start "$(world_unit "$VARIANT")"
write_active_variant "$VARIANT"
"$SCRIPT_DIR/status.sh" "$VARIANT"
if [[ "$UNIT_SCOPE" == "user" ]]; then
  log "логи: journalctl --user -u $(world_unit "$VARIANT") -f"
else
  log "логи: journalctl -u $(world_unit "$VARIANT") -f"
fi
log "глушить: scripts/stop.sh"
