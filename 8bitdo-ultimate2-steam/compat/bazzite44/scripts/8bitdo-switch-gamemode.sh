#!/bin/bash
# Переход в Game Mode как ярлыки GameMode (Monitor) / GameMode (TV):
#   1) пишем OUTPUT_CONNECTOR в ~/.config/environment.d/10-gamescope-session.conf
#   2) systemctl start return-to-gamemode.service
#
# Usage:
#   8bitdo-switch-gamemode monitor   # DP-1 (по умолчанию)
#   8bitdo-switch-gamemode tv        # DP-3
#   8bitdo-switch-gamemode           # без смены OUTPUT (только service / fallback)
set -euo pipefail

MODE="${1:-}"
CFG="${HOME}/.config/8bitdo/gamemode.conf"
ENV_FILE="${HOME}/.config/environment.d/10-gamescope-session.conf"
MONITOR_CONNECTOR="DP-1"
TV_CONNECTOR="DP-3"

log() {
  echo "8bitdo-switch-gamemode: $*" >&2
  logger -t 8bitdo-switch-gamemode -- "$*" 2>/dev/null || true
}

if [[ -f "$CFG" ]]; then
  # shellcheck disable=SC1090
  while IFS='=' read -r key val; do
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    key="$(echo "$key" | tr -d '[:space:]')"
    val="$(echo "$val" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    case "$key" in
      monitor_connector) MONITOR_CONNECTOR="$val" ;;
      tv_connector) TV_CONNECTOR="$val" ;;
      env_file)
        ENV_FILE="${val/#\~/$HOME}"
        ;;
    esac
  done < <(grep -E '^(monitor_connector|tv_connector|env_file)=' "$CFG" 2>/dev/null || true)
fi

write_connector() {
  local connector="$1"
  mkdir -p "$(dirname "$ENV_FILE")"
  printf "OUTPUT_CONNECTOR=%s\n" "$connector" >"$ENV_FILE"
  log "wrote $ENV_FILE → OUTPUT_CONNECTOR=$connector"
}

start_gamemode() {
  # Как на Desktop ярлыках пользователя
  if systemctl cat return-to-gamemode.service >/dev/null 2>&1; then
    log "systemctl start return-to-gamemode.service"
    systemctl start return-to-gamemode.service
    return 0
  fi
  if systemctl --user cat return-to-gamemode.service >/dev/null 2>&1; then
    log "systemctl --user start return-to-gamemode.service"
    systemctl --user start return-to-gamemode.service
    return 0
  fi
  if command -v steamosctl >/dev/null 2>&1; then
    log "fallback: steamosctl switch-to-game-mode"
    steamosctl switch-to-game-mode
    return 0
  fi
  if [[ -x /usr/bin/return-to-gamemode ]]; then
    log "fallback: /usr/bin/return-to-gamemode"
    /usr/bin/return-to-gamemode
    return 0
  fi
  if [[ -x /usr/bin/steamos-session-select ]]; then
    log "fallback: steamos-session-select gamescope"
    /usr/bin/steamos-session-select gamescope
    return 0
  fi
  log "ERROR: return-to-gamemode.service / steamosctl / return-to-gamemode not found"
  return 1
}

case "$MODE" in
  monitor|mon|dp-1|DP-1)
    write_connector "$MONITOR_CONNECTOR"
    ;;
  tv|TV|dp-3|DP-3)
    write_connector "$TV_CONNECTOR"
    ;;
  ""|default|none)
    log "no OUTPUT_CONNECTOR change"
    ;;
  *)
    log "unknown mode '$MODE' (use: monitor | tv)"
    exit 2
    ;;
esac

start_gamemode
