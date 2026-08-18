#!/usr/bin/env bash
# Запуск выбранного варианта (auth + world). Другие стеки глушатся.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

resolve_variant "${1:-}"
systemd_for_variant "$VARIANT"

if sc is-active --quiet "$(world_unit "$VARIANT")" 2>/dev/null; then
  log "уже запущен $VARIANT"
  exec "$SCRIPT_DIR/status.sh" "$VARIANT"
fi

if pgrep -x worldserver >/dev/null 2>&1 || pgrep -x authserver >/dev/null 2>&1; then
  die "authserver/worldserver крутятся не через systemd (tmux?). Остановите консоль или: scripts/stop.sh"
fi

$SUDO systemctl start mysql 2>/dev/null || $SUDO systemctl start mysqld 2>/dev/null || true

for v in playerbots npcbots lonewolf; do
  if [[ "$v" == "$VARIANT" ]]; then
    continue
  fi
  if [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/ac-${v}-world.service" ]] || [[ -f "/etc/systemd/system/ac-${v}-world.service" ]]; then
    systemd_for_variant "$v"
    sc stop "$(world_unit "$v")" "$(auth_unit "$v")" 2>/dev/null || true
  fi
done

systemd_for_variant "$VARIANT"
log "старт auth ($VARIANT)"
sc start "$(auth_unit "$VARIANT")"
sleep 1
log "старт world ($VARIANT) — холодный старт может долго импортировать SQL"
sc start "$(world_unit "$VARIANT")"
write_active_variant "$VARIANT"
"$SCRIPT_DIR/status.sh" "$VARIANT"
if [[ "$UNIT_SCOPE" == "user" ]]; then
  log "логи: journalctl --user -u $(world_unit "$VARIANT") -f"
else
  log "логи: journalctl -u $(world_unit "$VARIANT") -f"
fi
log "глушить: scripts/stop.sh"
