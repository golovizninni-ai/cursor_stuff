#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

resolve_variant "${1:-}"
MODE="$(read_install_mode "$VARIANT")"

echo "вариант: $VARIANT  режим: $MODE"
echo "активный стек: $(read_active_variant 2>/dev/null || echo «не задан»)"

if [[ "$MODE" == "docker" ]]; then
  dc ps || true
  echo
  echo "логи: docker compose -p $(compose_project "$VARIANT") --project-directory $SRC logs -f ac-worldserver"
  echo "консоль: docker attach $(docker_world_container "$VARIANT")"
  exit 0
fi

systemd_for_variant "$VARIANT"
echo "systemd scope: $UNIT_SCOPE"
sc --no-pager --full status "$(auth_unit "$VARIANT")" "$(world_unit "$VARIANT")" || true
echo
echo "автозапуск:"
sc is-enabled "$(auth_unit "$VARIANT")" 2>/dev/null || true
sc is-enabled "$(world_unit "$VARIANT")" 2>/dev/null || true
