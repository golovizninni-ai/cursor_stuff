#!/bin/bash
# Снять всё, что ставит install-all.sh (43/44).
#
#   sudo ./scripts/uninstall-all.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Запустите через sudo: sudo $0" >&2
  exit 1
fi

REAL_USER="${SUDO_USER:-}"
if [[ -z "$REAL_USER" || "$REAL_USER" == "root" ]]; then
  REAL_USER="$(logname 2>/dev/null || true)"
fi
USER_HOME=""
USER_UID=""
RUNTIME_DIR=""
if [[ -n "$REAL_USER" && "$REAL_USER" != "root" ]]; then
  USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
  USER_UID="$(id -u "$REAL_USER")"
  RUNTIME_DIR="/run/user/${USER_UID}"
fi

echo "=== uninstall sleep ==="
bash "$ROOT/scripts/uninstall-sleep.sh" || true

echo "=== uninstall wakeup ==="
bash "$ROOT/scripts/uninstall-wakeup-only-dongle.sh" || true

echo "=== uninstall reenum ==="
bash "$ROOT/scripts/uninstall-reenum.sh" || true

echo "=== uninstall gamemode udev ==="
bash "$ROOT/scripts/uninstall-gamemode-hotkey-udev.sh" || true

echo "=== uninstall bazzite44 compat ==="
bash "$ROOT/compat/bazzite44/scripts/uninstall-bazzite44.sh" || true

echo "=== uninstall hidraw rule ==="
rm -f /etc/udev/rules.d/71-8bitdo-u2w.rules
udevadm control --reload || true

echo "=== uninstall user hotkey ==="
if [[ -n "$REAL_USER" && -n "$USER_HOME" ]]; then
  sudo -u "$REAL_USER" -H \
    env HOME="$USER_HOME" XDG_RUNTIME_DIR="$RUNTIME_DIR" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=${RUNTIME_DIR}/bus" \
    bash "$ROOT/scripts/uninstall-gamemode-hotkey.sh" || true
  echo "=== uninstall HDR nudge (если ставили) ==="
  sudo -u "$REAL_USER" -H \
    env HOME="$USER_HOME" XDG_RUNTIME_DIR="$RUNTIME_DIR" \
    bash "$ROOT/scripts/uninstall-hdr-workaround.sh" || true
else
  echo "WARN: не удалось снять user-службу (нет SUDO_USER). Снимите вручную:"
  echo "  ./scripts/uninstall-gamemode-hotkey.sh"
  echo "  ./scripts/uninstall-hdr-workaround.sh"
fi

rm -f /usr/local/bin/8bitdo-switch-gamemode /usr/local/bin/8bitdo-hdr-nudge.sh

systemctl daemon-reload || true

echo ""
echo "Всё снято (конфиги /etc/8bitdo-sleep.conf и ~/.config/8bitdo/ оставлены)."
echo "При необходимости удалите их вручную."
