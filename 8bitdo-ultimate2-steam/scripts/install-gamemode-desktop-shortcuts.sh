#!/bin/bash
# Поставить ярлыки GameMode (Monitor/TV) на рабочий стол — без sudo/pkexec.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DESK="${XDG_DESKTOP_DIR:-$HOME/Desktop}"
[[ -d "$DESK" ]] || DESK="$HOME/Desktop"
mkdir -p "$DESK"

MONITOR="DP-1"
TV="DP-3"
CFG="${HOME}/.config/8bitdo/gamemode.conf"
if [[ -f "$CFG" ]]; then
  while IFS='=' read -r k v; do
    [[ "$k" =~ ^[[:space:]]*# ]] && continue
    k="$(echo "$k" | tr -d '[:space:]')"
    v="$(echo "$v" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    case "$k" in
      monitor_connector) MONITOR="$v" ;;
      tv_connector) TV="$v" ;;
    esac
  done < <(grep -E '^(monitor_connector|tv_connector)=' "$CFG" 2>/dev/null || true)
fi

sed "s/DP-1/${MONITOR}/g" "$ROOT/desktop/GameMode-Monitor.desktop" \
  >"$DESK/GameMode-Monitor.desktop"
sed "s/DP-3/${TV}/g" "$ROOT/desktop/GameMode-TV.desktop" \
  >"$DESK/GameMode-TV.desktop"
chmod +x "$DESK/GameMode-Monitor.desktop" "$DESK/GameMode-TV.desktop"

if command -v gio >/dev/null 2>&1; then
  gio set "$DESK/GameMode-Monitor.desktop" metadata::trusted true 2>/dev/null || true
  gio set "$DESK/GameMode-TV.desktop" metadata::trusted true 2>/dev/null || true
fi

echo "Installed:"
echo "  $DESK/GameMode-Monitor.desktop  ($MONITOR)"
echo "  $DESK/GameMode-TV.desktop       ($TV)"
echo "Если KDE: ПКМ по ярлыку → Allow Launching."
echo "Проверка: steamosctl switch-to-game-mode"
