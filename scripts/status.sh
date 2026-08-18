#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

resolve_variant "${1:-}"
systemd_for_variant "$VARIANT"

echo "вариант: $VARIANT  scope: $UNIT_SCOPE"
sc --no-pager --full status "$(auth_unit "$VARIANT")" "$(world_unit "$VARIANT")" || true
echo
echo "активный стек: $(read_active_variant 2>/dev/null || echo «не задан»)"
echo "автозапуск:"
sc is-enabled "$(auth_unit "$VARIANT")" 2>/dev/null || true
sc is-enabled "$(world_unit "$VARIANT")" 2>/dev/null || true
