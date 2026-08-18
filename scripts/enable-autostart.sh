#!/usr/bin/env bash
# Включить автозапуск после перезагрузки ВМ (когда сервер оставляете надолго).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

resolve_variant "${1:-}"
systemd_for_variant "$VARIANT"

$SUDO systemctl enable mysql 2>/dev/null || $SUDO systemctl enable mysqld 2>/dev/null || true
$SUDO systemctl start mysql 2>/dev/null || $SUDO systemctl start mysqld 2>/dev/null || true

if [[ "$UNIT_SCOPE" == "user" ]]; then
  log "user-systemd: включаю linger, чтобы сервисы жили без SSH-сессии"
  if command -v loginctl >/dev/null; then
    loginctl enable-linger "$AC_USER" 2>/dev/null || $SUDO loginctl enable-linger "$AC_USER"
  fi
fi

sc enable "$(auth_unit "$VARIANT")" "$(world_unit "$VARIANT")"
write_active_variant "$VARIANT"
log "автозапуск $VARIANT включён"
log "сейчас поднять: scripts/start.sh $VARIANT"
log "снять с автозапуска: scripts/disable-autostart.sh $VARIANT"
sc is-enabled "$(auth_unit "$VARIANT")"
sc is-enabled "$(world_unit "$VARIANT")"
