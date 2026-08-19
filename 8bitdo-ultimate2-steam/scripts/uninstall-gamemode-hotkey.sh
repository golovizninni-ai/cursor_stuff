#!/bin/bash
# Удаление user-службы Game Mode hotkey.
set -euo pipefail

BIN="${HOME}/.local/bin/8bitdo-gamemode-hotkey.py"
UNIT="${HOME}/.config/systemd/user/8bitdo-gamemode-hotkey.service"

systemctl --user disable --now 8bitdo-gamemode-hotkey.service 2>/dev/null || true
rm -f "$UNIT" "$BIN"
systemctl --user daemon-reload
systemctl --user reset-failed 8bitdo-gamemode-hotkey.service 2>/dev/null || true

echo "Removed 8bitdo-gamemode-hotkey user service and script."
echo "Config kept at ~/.config/8bitdo/gamemode.conf (remove manually if not needed)."
