#!/bin/bash
# Универсальный переход в Game Mode (Bazzite 43 и 44 deck).
# На 44: steamosctl switch-to-game-mode (через steamos-manager).
# На 43: return-to-gamemode / steamos-session-select.
set -euo pipefail

log() {
  echo "8bitdo-switch-gamemode: $*" >&2
  logger -t 8bitdo-switch-gamemode -- "$*" 2>/dev/null || true
}

try_cmd() {
  local bin="$1"
  shift
  if command -v "$bin" >/dev/null 2>&1; then
    log "exec: $bin $*"
    exec "$bin" "$@"
  fi
  return 1
}

# 1) Прямой steamosctl (Bazzite 44 deck)
if command -v steamosctl >/dev/null 2>&1; then
  log "using steamosctl switch-to-game-mode"
  exec steamosctl switch-to-game-mode
fi

# 2) Штатный ярлык (обёртка над steamosctl на 44)
if [[ -x /usr/bin/return-to-gamemode ]]; then
  log "using /usr/bin/return-to-gamemode"
  exec /usr/bin/return-to-gamemode
fi

# 3) Deprecated shim (на 44 зовёт steamosctl с args)
if [[ -x /usr/bin/steamos-session-select ]]; then
  log "using steamos-session-select gamescope"
  exec /usr/bin/steamos-session-select gamescope
fi

if [[ -x /usr/libexec/os-session-select ]]; then
  log "using os-session-select gamescope"
  exec /usr/libexec/os-session-select gamescope
fi

log "ERROR: no Game Mode switch command found (need steamos-manager / return-to-gamemode)"
exit 1
