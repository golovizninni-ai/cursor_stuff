#!/bin/bash
# Установка совместимости Bazzite 44 для 8BitDo Ultimate 2 скриптов.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
COMPAT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Запустите через sudo: sudo $0" >&2
  exit 1
fi

REAL_USER="${SUDO_USER:-}"
if [[ -z "$REAL_USER" || "$REAL_USER" == "root" ]]; then
  REAL_USER="$(logname 2>/dev/null || true)"
fi
USER_HOME="/home/${REAL_USER:-}"
if [[ -z "$REAL_USER" || ! -d "$USER_HOME" ]]; then
  echo "Не удалось определить домашний каталог пользователя" >&2
  exit 1
fi

echo "=== Bazzite version hint ==="
if [[ -f /usr/share/ublue-os/image-info.json ]]; then
  jq -r '"\(.["image-name"] // .image_name // "?") fedora=\(.["fedora-version"] // .fedora_version // "?")"' \
    /usr/share/ublue-os/image-info.json 2>/dev/null || cat /usr/share/ublue-os/image-info.json
fi
echo ""

# 1) InputPlumber ignore
if command -v inputplumber >/dev/null 2>&1 || systemctl list-unit-files inputplumber.service >/dev/null 2>&1; then
  install -d /etc/inputplumber/devices.d
  install -m 0644 "$COMPAT/inputplumber/19-custom-2dc8_6012.yaml" \
    /etc/inputplumber/devices.d/19-custom-2dc8_6012.yaml
  install -m 0644 "$COMPAT/inputplumber/19-custom-2dc8_310b.yaml" \
    /etc/inputplumber/devices.d/19-custom-2dc8_310b.yaml
  echo "Installed InputPlumber ignore for 2dc8:6012 and 2dc8:310b"
  systemctl try-reload-or-restart inputplumber.service 2>/dev/null || true
else
  echo "InputPlumber не найден — ignore YAML пропущен (не deck-образ?)"
fi

# 2) Switch wrapper
install -m 0755 "$COMPAT/scripts/8bitdo-switch-gamemode.sh" /usr/local/bin/8bitdo-switch-gamemode
echo "Installed /usr/local/bin/8bitdo-switch-gamemode"

# 3) User gamemode config
CFG_DIR="$USER_HOME/.config/8bitdo"
install -d -o "$REAL_USER" -g "$REAL_USER" "$CFG_DIR"
install -m 0644 -o "$REAL_USER" -g "$REAL_USER" \
  "$COMPAT/config/8bitdo-gamemode.conf" "$CFG_DIR/gamemode.conf"
echo "Updated $CFG_DIR/gamemode.conf → switch via 8bitdo-switch-gamemode"

# 4) steamosctl check
if ! command -v steamosctl >/dev/null 2>&1; then
  echo ""
  echo "WARN: steamosctl не найден. На Bazzite 44 deck нужен steamos-manager."
  echo "      На desktop-образе без Game Mode hotkey может не работать."
else
  echo "OK: steamosctl present"
fi

echo ""
echo "Готово. Рекомендуется reboot (InputPlumber)."
echo "Затем: systemctl --user restart 8bitdo-gamemode-hotkey.service"
echo "Документация: $COMPAT/README.md"
