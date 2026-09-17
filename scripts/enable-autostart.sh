#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

resolve_variant "${1:-}"
require_native_binaries "$VARIANT"
systemd_for_variant "$VARIANT"

$SUDO systemctl enable mysql 2>/dev/null || $SUDO systemctl enable mysqld 2>/dev/null || true
$SUDO systemctl start mysql 2>/dev/null || $SUDO systemctl start mysqld 2>/dev/null || true

if [[ "$UNIT_SCOPE" == "user" ]]; then
  log "user-systemd: linger, чтобы сервисы жили без SSH"
  if command -v loginctl >/dev/null; then
    loginctl enable-linger "$AC_USER" 2>/dev/null || $SUDO loginctl enable-linger "$AC_USER"
  fi
fi

sc enable "$(auth_unit "$VARIANT")" "$(world_unit "$VARIANT")"
write_active_variant "$VARIANT"
log "автозапуск $VARIANT включён"
if [[ -f "$AC_ROOT/$VARIANT/ollama-chat" ]]; then
  $SUDO systemctl enable --now ollama 2>/dev/null || true
  log "ollama.service тоже в автозапуске (чат ботов)"
fi
log "сейчас поднять: scripts/start.sh $VARIANT"
log "снять: scripts/disable-autostart.sh $VARIANT"
sc is-enabled "$(auth_unit "$VARIANT")"
sc is-enabled "$(world_unit "$VARIANT")"
