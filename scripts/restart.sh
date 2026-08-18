#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
VARIANT="${1:-}"
"$SCRIPT_DIR/stop.sh" ${VARIANT:+"$VARIANT"}
"$SCRIPT_DIR/start.sh" ${VARIANT:+"$VARIANT"}
