#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

resolve_variant "${1:-}"
systemd_for_variant "$VARIANT"
sc disable "$(auth_unit "$VARIANT")" "$(world_unit "$VARIANT")" || true
log "автозапуск $VARIANT выключен (процессы могли остаться)"
log "глушить: scripts/stop.sh $VARIANT"
