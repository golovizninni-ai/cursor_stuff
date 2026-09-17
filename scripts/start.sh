#!/usr/bin/env bash
# Запуск выбранного варианта (systemd). Один стек на 3724/8085.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

ARG="${1:-}"
if [[ -z "$ARG" ]]; then
  ARG="$(read_active_variant || true)"
  if [[ -z "$ARG" ]]; then
    die "укажите вариант: playerbots|npcbots|lonewolf
Уже стоят: $(list_installed_variants | tr '\n' ' ' || echo «ничего»)
После install активный пишется сам; либо: scripts/start.sh <вариант>"
  fi
  if ! variant_installed "$ARG"; then
    die "active-variant=$ARG, но установка неполная (нет бинарников/юнитов).
Укажите явно рабочий вариант: scripts/start.sh <вариант>
Или доставьте: scripts/install.sh $ARG
Сейчас стоят: $(list_installed_variants | tr '\n' ' ' || echo «ничего»)"
  fi
  log "вариант из active-variant: $ARG"
fi

resolve_variant "$ARG"
require_native_binaries "$VARIANT"
stop_other_variants "$VARIANT"
systemd_for_variant "$VARIANT"

if sc is-active --quiet "$(world_unit "$VARIANT")" 2>/dev/null; then
  log "уже запущен $VARIANT"
  write_active_variant "$VARIANT"
  exec "$SCRIPT_DIR/status.sh" "$VARIANT"
fi

if pgrep -x worldserver >/dev/null 2>&1 || pgrep -x authserver >/dev/null 2>&1; then
  die "authserver/worldserver крутятся не через systemd (tmux?).
Остановите консоль или: scripts/stop.sh"
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
log "другой вариант: scripts/switch.sh <вариант>"
