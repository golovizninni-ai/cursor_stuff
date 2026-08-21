#!/bin/bash
# Установка user-службы: Guide + LT + RT -> Game Mode в Desktop Mode.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${HOME}/.local/bin"
CFG_DIR="${HOME}/.config/8bitdo"
UNIT_DIR="${HOME}/.config/systemd/user"

mkdir -p "$BIN" "$CFG_DIR" "$UNIT_DIR"

install -m 0755 "$ROOT/scripts/8bitdo-gamemode-hotkey.py" "$BIN/8bitdo-gamemode-hotkey.py"

if [[ ! -f "$CFG_DIR/gamemode.conf" ]]; then
  install -m 0644 "$ROOT/config/8bitdo-gamemode.conf" "$CFG_DIR/gamemode.conf"
  echo "Config: $CFG_DIR/gamemode.conf"
else
  echo "Config already exists: $CFG_DIR/gamemode.conf (not overwritten)"
fi

install -m 0644 "$ROOT/systemd/8bitdo-gamemode-hotkey.service" \
  "$UNIT_DIR/8bitdo-gamemode-hotkey.service"

systemctl --user daemon-reload
systemctl --user enable --now 8bitdo-gamemode-hotkey.service

echo ""
echo "Installed 8bitdo-gamemode-hotkey (user service)."
echo "Status:  systemctl --user status 8bitdo-gamemode-hotkey.service"
echo "Logs:    journalctl --user -u 8bitdo-gamemode-hotkey.service -f"
echo "Devices: $BIN/8bitdo-gamemode-hotkey.py --list-devices"
echo ""
echo "Права на Bazzite: sudo ./scripts/install-gamemode-hotkey-udev.sh"
echo "  (MODE 0666 + chmod при подключении геймпада; без SupplementaryGroups)"
echo "  ./scripts/8bitdo-gamemode-check-perms.sh"
echo ""
echo "Комбо: Guide (Home) + LT + RT ~0.4 с -> Game Mode."
echo "После срабатывания служба завершается до следующего входа в Plasma."
