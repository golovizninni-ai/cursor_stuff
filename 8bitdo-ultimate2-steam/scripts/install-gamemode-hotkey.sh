#!/bin/bash
# Установка user-службы: Start+Select+LB+RB (Monitor) / +LT+RT (TV) → Game Mode.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${HOME}/.local/bin"
CFG_DIR="${HOME}/.config/8bitdo"
UNIT_DIR="${HOME}/.config/systemd/user"

mkdir -p "$BIN" "$CFG_DIR" "$UNIT_DIR"

install -m 0755 "$ROOT/scripts/8bitdo-gamemode-hotkey.py" "$BIN/8bitdo-gamemode-hotkey.py"
install -m 0644 "$ROOT/config/8bitdo-gamemode.conf" "$CFG_DIR/gamemode.conf"
echo "Config: $CFG_DIR/gamemode.conf"
echo "  Monitor: Start+Select+LB+RB → DP-1"
echo "  TV:      Start+Select+LT+RT → DP-3"

if [[ "$(id -u)" -eq 0 ]] || [[ -w /usr/local/bin ]]; then
  install -m 0755 "$ROOT/compat/bazzite44/scripts/8bitdo-switch-gamemode.sh" \
    /usr/local/bin/8bitdo-switch-gamemode
  echo "Installed /usr/local/bin/8bitdo-switch-gamemode"
elif [[ ! -x /usr/local/bin/8bitdo-switch-gamemode ]]; then
  echo "WARN: нет /usr/local/bin/8bitdo-switch-gamemode — поставьте через sudo ./scripts/install-all.sh"
fi

install -m 0644 "$ROOT/systemd/8bitdo-gamemode-hotkey.service" \
  "$UNIT_DIR/8bitdo-gamemode-hotkey.service"

systemctl --user daemon-reload
systemctl --user enable --now 8bitdo-gamemode-hotkey.service

echo ""
echo "Installed. Status: systemctl --user status 8bitdo-gamemode-hotkey.service"
echo "Test: /usr/local/bin/8bitdo-switch-gamemode monitor"
echo "      /usr/local/bin/8bitdo-switch-gamemode tv"
echo "Buttons: $BIN/8bitdo-gamemode-hotkey.py --monitor"
