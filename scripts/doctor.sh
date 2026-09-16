#!/usr/bin/env bash
# Диагностика после неудачной установки / start.sh.
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
MODE="$(read_install_mode "$VARIANT")"
DEPLOY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== doctor: $VARIANT ==="
echo "деплой:     $DEPLOY_ROOT"
echo "AC_ROOT:    $AC_ROOT"
echo "SRC:        $SRC"
echo "PREFIX:     $PREFIX"
echo "install-mode: $MODE ($(install_mode_file "$VARIANT"))"

echo
echo "--- бинарники (native) ---"
for b in authserver worldserver; do
  f="$PREFIX/bin/$b"
  if [[ -x "$f" ]]; then
    echo "  OK  $f"
  elif [[ -f "$f" ]]; then
    echo "  НЕ ИСПОЛНЯЕМЫЙ  $f"
  else
    echo "  НЕТ  $f"
  fi
done

echo
echo "--- docker ---"
if [[ -f "$SRC/docker-compose.yml" ]]; then
  echo "  OK  $SRC/docker-compose.yml"
else
  echo "  НЕТ  $SRC/docker-compose.yml"
fi
if [[ -f "$SRC/docker-compose.override.yml" ]]; then
  echo "  OK  override (mem_limit и env)"
else
  echo "  нет override (нормально до install-docker.sh)"
fi
if command -v docker >/dev/null; then
  for c in "$(docker_world_container "$VARIANT")" "$(docker_auth_container "$VARIANT")" "$(docker_db_container "$VARIANT")"; do
    if docker inspect "$c" >/dev/null 2>&1; then
      st="$(docker inspect -f '{{.State.Status}} (restarts={{.RestartCount}})' "$c" 2>/dev/null || echo '?')"
      echo "  контейнер $c: $st"
    fi
  done
fi

echo
echo "--- systemd ---"
user_unit="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/ac-${VARIANT}-world.service"
sys_unit="/etc/systemd/system/ac-${VARIANT}-world.service"
if [[ -f "$user_unit" ]]; then
  echo "  user unit: $user_unit"
elif [[ -f "$sys_unit" ]]; then
  echo "  system unit: $sys_unit"
else
  echo "  юнитов нет (нормально до 04-configure / install.sh)"
fi
if [[ -f "$user_unit" ]]; then
  systemctl --user --no-pager --full status "$(auth_unit "$VARIANT")" "$(world_unit "$VARIANT")" 2>/dev/null || true
elif [[ -f "$sys_unit" ]]; then
  if [[ "${EUID}" -eq 0 ]]; then
    systemctl --no-pager --full status "$(auth_unit "$VARIANT")" "$(world_unit "$VARIANT")" 2>/dev/null || true
  else
    sudo systemctl --no-pager --full status "$(auth_unit "$VARIANT")" "$(world_unit "$VARIANT")" 2>/dev/null || true
  fi
fi

echo
echo "--- что пошло не так (типично) ---"
issues=0

if [[ "$MODE" == "native" ]] && ! native_binaries_ok "$VARIANT"; then
  if [[ -f "$user_unit" || -f "$sys_unit" ]]; then
    echo "  [!] systemd-юниты есть, бинарников нет → journalctl status=203/EXEC"
    echo "      Остановите цикл: systemctl --user stop ac-${VARIANT}-auth ac-${VARIANT}-world"
    echo "      systemctl --user disable ac-${VARIANT}-auth ac-${VARIANT}-world"
    issues=$((issues + 1))
  fi
fi

if [[ "$MODE" == "native" && -f "$SRC/docker-compose.override.yml" && ! -f "$(install_mode_file "$VARIANT")" ]]; then
  echo "  [!] Похоже на оборванный install-docker.sh (override есть, install-mode не записан)"
  issues=$((issues + 1))
fi

if [[ "$MODE" == "docker" ]] && [[ ! -f "$SRC/docker-compose.yml" ]]; then
  echo "  [!] install-mode=docker, но compose нет — переустановите install-docker.sh"
  issues=$((issues + 1))
fi

if [[ ! -d "$SRC/.git" ]]; then
  echo "  [!] Нет клона исходников — scripts/02-clone.sh $VARIANT или install.sh"
  issues=$((issues + 1))
fi

echo
echo "--- рекомендация ---"
if [[ "$issues" -eq 0 ]] && native_binaries_ok "$VARIANT"; then
  echo "  Native готов: scripts/start.sh $VARIANT"
elif [[ -f "$SRC/docker-compose.yml" ]]; then
  echo "  1) cd $DEPLOY_ROOT && git pull   # обновить скрипты"
  echo "  2) systemctl --user stop ac-${VARIANT}-auth ac-${VARIANT}-world 2>/dev/null || true"
  echo "  3) Один путь:"
  echo "       Docker:  ./scripts/install-docker.sh $VARIANT"
  echo "       Native:  ./scripts/install.sh $VARIANT"
  echo "  4) ./scripts/start.sh $VARIANT"
else
  echo "  ./scripts/install.sh $VARIANT"
fi
