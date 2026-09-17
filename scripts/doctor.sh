#!/usr/bin/env bash
# Диагностика после сбоя установки / странного start.sh.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

VARIANT="${1:-}"
if [[ -z "$VARIANT" ]]; then
  VARIANT="$(read_active_variant || true)"
fi
[[ -n "$VARIANT" ]] || die "usage: $0 playerbots|npcbots|lonewolf"

variant_paths "$VARIANT"
DEPLOY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== doctor: $VARIANT ==="
echo "деплой:     $DEPLOY_ROOT"
echo "AC_ROOT:    $AC_ROOT"
echo "SRC:        $SRC"
echo "PREFIX:     $PREFIX"
echo "active:     $(read_active_variant || echo «нет»)"
echo "установлены: $(list_installed_variants | tr '\n' ' ' || echo «ничего»)"
echo "shared IP:  $(read_shared_realm_address || echo «нет»)"

echo
echo "--- бинарники ---"
for b in authserver worldserver; do
  f="$PREFIX/bin/$b"
  if [[ -x "$f" ]]; then echo "  OK  $f"
  elif [[ -f "$f" ]]; then echo "  НЕ ИСПОЛНЯЕМЫЙ  $f"
  else echo "  НЕТ  $f"
  fi
done

echo
echo "--- systemd ---"
user_unit="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/ac-${VARIANT}-world.service"
sys_unit="/etc/systemd/system/ac-${VARIANT}-world.service"
if [[ -f "$user_unit" ]]; then
  echo "  user unit: $user_unit"
  systemctl --user --no-pager --full status "$(auth_unit "$VARIANT")" "$(world_unit "$VARIANT")" 2>/dev/null || true
elif [[ -f "$sys_unit" ]]; then
  echo "  system unit: $sys_unit"
  $SUDO systemctl --no-pager --full status "$(auth_unit "$VARIANT")" "$(world_unit "$VARIANT")" 2>/dev/null || true
else
  echo "  юнитов нет — scripts/install.sh $VARIANT"
fi

echo
echo "--- legacy docker (если остался от старых попыток) ---"
if command -v docker >/dev/null 2>&1; then
  docker ps -a --filter "name=ac-${VARIANT}-" --format '  {{.Names}}  {{.Status}}' 2>/dev/null || echo "  нет"
else
  echo "  docker не установлен / не в PATH"
fi

echo
echo "--- рекомендация ---"
if variant_installed "$VARIANT"; then
  echo "  OK: scripts/start.sh $VARIANT   или   scripts/switch.sh $VARIANT"
else
  echo "  1) cd $DEPLOY_ROOT && git pull"
  echo "  2) ./scripts/uninstall.sh -y $VARIANT   # снести обломки"
  echo "  3) ./scripts/install.sh $VARIANT"
  echo "  4) первый worldserver в tmux → account create → set-realm-address → start.sh"
fi
