#!/bin/bash
# Всё в одном: sleep, wake, re-enum, Start+Select+LB+RB→Game Mode, (на 44 — InputPlumber + steamosctl).
# Работает на Bazzite 43 и 44 (deck/HTPC).
#
#   sudo ./scripts/install-all.sh
#   sudo ./scripts/install-all.sh --dry-run
#   sudo ./scripts/install-all.sh --no-44    # не ставить слой 44 даже если steamosctl есть
#   sudo ./scripts/install-all.sh --force-44 # всегда ставить слой 44
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DRY_RUN=0
NO_44=0
FORCE_44=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --no-44) NO_44=1 ;;
    --force-44) FORCE_44=1 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Запустите через sudo: sudo $0" >&2
  exit 1
fi

REAL_USER="${SUDO_USER:-}"
if [[ -z "$REAL_USER" || "$REAL_USER" == "root" ]]; then
  REAL_USER="$(logname 2>/dev/null || true)"
fi
if [[ -z "$REAL_USER" || "$REAL_USER" == "root" ]]; then
  echo "Не удалось определить обычного пользователя (SUDO_USER). Запустите: sudo -u ВАШ_ЮЗЕР sudo $0" >&2
  exit 1
fi
USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
USER_UID="$(id -u "$REAL_USER")"
RUNTIME_DIR="/run/user/${USER_UID}"

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY: $*"
  else
    "$@"
  fi
}

run_user() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY(user $REAL_USER): $*"
  else
    sudo -u "$REAL_USER" -H \
      env HOME="$USER_HOME" XDG_RUNTIME_DIR="$RUNTIME_DIR" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=${RUNTIME_DIR}/bus" \
      "$@"
  fi
}

detect_need_44() {
  if [[ "$FORCE_44" -eq 1 ]]; then
    return 0
  fi
  if [[ "$NO_44" -eq 1 ]]; then
    return 1
  fi
  local fedora=""
  if [[ -f /usr/share/ublue-os/image-info.json ]]; then
    fedora="$(jq -r '."fedora-version" // .fedora_version // empty' /usr/share/ublue-os/image-info.json 2>/dev/null || true)"
  fi
  if [[ "$fedora" == "44" ]]; then
    return 0
  fi
  if command -v steamosctl >/dev/null 2>&1; then
    return 0
  fi
  if systemctl list-unit-files inputplumber.service >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

echo "=========================================="
echo " 8BitDo Ultimate 2 — install ALL"
echo " User: $REAL_USER  Home: $USER_HOME"
echo "=========================================="
echo ""

if [[ -x "$ROOT/scripts/8bitdo-detect-bazzite.sh" ]]; then
  bash "$ROOT/scripts/8bitdo-detect-bazzite.sh" || true
  echo ""
fi

NEED_44=0
if detect_need_44; then
  NEED_44=1
  echo ">>> Обнаружен стек 44 / steamosctl / InputPlumber — поставим compat/bazzite44"
else
  echo ">>> Похоже на Bazzite 43 (или без steamosctl) — слой 44 пропустим"
fi
echo ""

echo "=== [1/6] Sleep / dock hooks ==="
run bash "$ROOT/scripts/install-sleep.sh"
echo ""

echo "=== [2/6] USB wake only 8BitDo ==="
run bash "$ROOT/scripts/install-wakeup-only-dongle.sh"
echo ""

echo "=== [3/6] D-Input USB re-enum ==="
run bash "$ROOT/scripts/install-reenum.sh"
echo ""

echo "=== [4/6] hidraw permissions (gyro / extended) ==="
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY: install 71-8bitdo-u2w.rules"
else
  install -m 0644 "$ROOT/udev/71-8bitdo-u2w.rules" /etc/udev/rules.d/71-8bitdo-u2w.rules
  udevadm control --reload
  udevadm trigger --subsystem-match=hidraw || true
  echo "Installed 71-8bitdo-u2w.rules"
fi
echo ""

echo "=== [5/6] Game Mode hotkey (udev + user service) ==="
run bash "$ROOT/scripts/install-gamemode-hotkey-udev.sh"
# user service: не через install-gamemode-hotkey.sh напрямую из root HOME
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY(user): install gamemode hotkey for $REAL_USER"
else
  run_user bash "$ROOT/scripts/install-gamemode-hotkey.sh"
fi
echo ""

echo "=== [6/6] Bazzite 44 compat ==="
if [[ "$NEED_44" -eq 1 ]]; then
  run bash "$ROOT/compat/bazzite44/scripts/install-bazzite44.sh"
else
  # На 43 всё равно ставим switch wrapper — hotkey умеет им пользоваться
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY: install 8bitdo-switch-gamemode wrapper only"
  else
    install -m 0755 "$ROOT/compat/bazzite44/scripts/8bitdo-switch-gamemode.sh" \
      /usr/local/bin/8bitdo-switch-gamemode
    echo "Installed /usr/local/bin/8bitdo-switch-gamemode (безопасно и на 43)"
  fi
fi
echo ""

# Принудительный chmod evdev, если геймпад уже включён
if [[ "$DRY_RUN" -eq 0 && -x /usr/local/bin/8bitdo-gamemode-chmod-evdev.sh ]]; then
  /usr/local/bin/8bitdo-gamemode-chmod-evdev.sh || true
fi

echo "=========================================="
echo " Готово."
echo "=========================================="
echo ""
echo "Дальше:"
echo "  1. reboot (особенно после 44 / InputPlumber)"
echo "  2. Smoke-test:"
echo "     - wake: sleep → Home / снять с дока (клава/мышь НЕ будят)"
echo "     - sleep/док: Big Picture sleep → док"
echo "     - D-Input: B+Home → гиро/L4 в Steam без Restart"
echo "     - Start+Select+LB+RB в Desktop → Game Mode"
echo ""
echo "Диагностика:"
echo "  sudo 8bitdo-wakeup-check.sh"
echo "  sudo -u $REAL_USER $ROOT/scripts/8bitdo-gamemode-check-perms.sh"
echo "  $ROOT/scripts/8bitdo-detect-bazzite.sh"
echo ""
echo "Снятие всего: sudo $ROOT/scripts/uninstall-all.sh"
