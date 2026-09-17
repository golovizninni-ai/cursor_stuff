#!/usr/bin/env bash
# Полная очистка варианта(ов): systemd + процессы + native БД + каталоги.
# Docker-стеки AzerothCore тоже снимаем, если остались от старых попыток.
# Не трогает compose *arr / Sonarr / Radarr.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
  cat <<EOF
usage: $0 [вариант|all] [опции]

  без аргумента / all   — все варианты (playerbots, npcbots, lonewolf)
  playerbots|npcbots|lonewolf — один вариант

опции:
  -y, --yes           без подтверждения
  --purge-data        удалить и \$AC_DATA (карты/dbc)
  --keep-data         оставить \$AC_DATA (по умолчанию)
  --keep-db           не DROP MySQL баз (ac_pb_*/ac_nb_*/ac_lw_*)
  -h, --help          эта справка

Примеры:
  $0 -y lonewolf
  $0 -y all --purge-data
EOF
}

YES=0
PURGE_DATA=0
KEEP_DB=0
TARGET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes) YES=1; shift ;;
    --purge-data) PURGE_DATA=1; shift ;;
    --keep-data) PURGE_DATA=0; shift ;;
    --keep-db) KEEP_DB=1; shift ;;
    -h|--help) usage; exit 0 ;;
    all|playerbots|npcbots|lonewolf)
      [[ -z "$TARGET" ]] || die "укажите только один вариант или all"
      TARGET="$1"
      shift
      ;;
    -*) die "неизвестная опция: $1 (см. --help)" ;;
    *) die "неизвестный аргумент: $1 (см. --help)" ;;
  esac
done

TARGET="${TARGET:-all}"
VARIANTS=()
if [[ "$TARGET" == "all" ]]; then
  VARIANTS=(playerbots npcbots lonewolf)
else
  VARIANTS=("$TARGET")
fi

confirm() {
  [[ "$YES" -eq 1 ]] && return 0
  echo
  echo "Будет удалено:"
  for v in "${VARIANTS[@]}"; do
    echo "  - $v: процессы, systemd, каталог $AC_ROOT/$v"
  done
  [[ "$KEEP_DB" -eq 0 ]] && echo "  - MySQL БД префиксов варианта"
  [[ "$PURGE_DATA" -eq 1 ]] && echo "  - клиентские data: $AC_DATA"
  echo "НЕ трогаем: *arr / Sonarr / Radarr, репозиторий деплоя."
  read -r -p "Продолжить? [y/N] " ans
  [[ "$ans" == "y" || "$ans" == "Y" || "$ans" == "yes" ]] || die "отменено"
}

uninstall_systemd() {
  local v="$1"
  local auth="ac-${v}-auth.service"
  local world="ac-${v}-world.service"

  if [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/${world}" ]]; then
    log "systemd --user: stop/disable $v"
    systemctl --user stop "$world" "$auth" 2>/dev/null || true
    systemctl --user disable "$world" "$auth" 2>/dev/null || true
    systemctl --user reset-failed "$world" "$auth" 2>/dev/null || true
  fi
  local user_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
  rm -f "$user_dir/ac-${v}-auth.service" "$user_dir/ac-${v}-world.service"
  systemctl --user daemon-reload 2>/dev/null || true

  if [[ -f "/etc/systemd/system/ac-${v}-world.service" ]] \
    || [[ -f "/etc/systemd/system/ac-${v}-auth.service" ]]; then
    log "systemd system: stop/disable $v"
    $SUDO systemctl stop "$world" "$auth" 2>/dev/null || true
    $SUDO systemctl disable "$world" "$auth" 2>/dev/null || true
    $SUDO rm -f "/etc/systemd/system/ac-${v}-auth.service" "/etc/systemd/system/ac-${v}-world.service"
    $SUDO systemctl daemon-reload 2>/dev/null || true
  fi
}

# Остатки старых docker-установок AC (не *arr).
scrub_legacy_docker() {
  local v="$1"
  command -v docker >/dev/null 2>&1 || return 0
  local proj="ac-${v}"
  local src="$AC_ROOT/$v/src"
  if [[ -f "$src/docker-compose.yml" ]]; then
    log "legacy docker compose down -v ($proj)"
    docker compose --project-name "$proj" --project-directory "$src" -f docker-compose.yml \
      down -v --remove-orphans 2>/dev/null || true
  fi
  docker compose -p "$proj" down -v --remove-orphans 2>/dev/null || true
  local c
  for c in \
    "ac-${v}-worldserver" "ac-${v}-authserver" "ac-${v}-database" \
    "ac-${v}-db-import" "ac-${v}-client-data" "ac-${v}-client-data-init"
  do
    docker rm -f "$c" 2>/dev/null || true
  done
  while read -r id; do
    [[ -n "$id" ]] || continue
    docker rm -f "$id" 2>/dev/null || true
  done < <(docker ps -aq --filter "name=ac-${v}-" 2>/dev/null || true)
  while read -r vol; do
    [[ -n "$vol" ]] || continue
    docker volume rm -f "$vol" 2>/dev/null || true
  done < <(docker volume ls -q --filter "name=${proj}_" 2>/dev/null || true)
}

kill_native_procs() {
  local v="$1"
  variant_paths "$v"
  if [[ -d "$PREFIX/bin" ]]; then
    pkill -TERM -f "$PREFIX/bin/(worldserver|authserver)" 2>/dev/null || true
    sleep 2
    pkill -KILL -f "$PREFIX/bin/(worldserver|authserver)" 2>/dev/null || true
  fi
}

drop_native_dbs() {
  local v="$1"
  [[ "$KEEP_DB" -eq 0 ]] || return 0
  variant_paths "$v"
  if ! command -v mysql >/dev/null 2>&1; then
    log "MySQL клиента нет — БД ${DB_PREFIX}_* пропускаю"
    return 0
  fi
  log "DROP DATABASE ${DB_PREFIX}_*"
  local db
  for db in \
    "${DB_PREFIX}_auth" "${DB_PREFIX}_world" \
    "${DB_PREFIX}_characters" "${DB_PREFIX}_playerbots"
  do
    $SUDO mysql --protocol=socket -uroot -e "DROP DATABASE IF EXISTS \`${db}\`;" 2>/dev/null || true
  done
}

confirm

for v in "${VARIANTS[@]}"; do
  echo
  log "=== uninstall $v ==="
  uninstall_systemd "$v"
  scrub_legacy_docker "$v"
  kill_native_procs "$v"
  drop_native_dbs "$v"
  if [[ -d "$AC_ROOT/$v" ]]; then
    log "удаляю $AC_ROOT/$v"
    rm -rf "$AC_ROOT/$v"
  fi
done

active="$(read_active_variant || true)"
for v in "${VARIANTS[@]}"; do
  if [[ "$active" == "$v" ]]; then
    rm -f "$(active_variant_file)"
    log "сброшен active-variant"
    break
  fi
done

left=0
for v in playerbots npcbots lonewolf; do
  [[ -e "$AC_ROOT/$v" ]] && left=1
done
if [[ "$left" -eq 0 ]]; then
  rm -f "$(active_variant_file)" 2>/dev/null || true
  rm -rf "$(shared_dir)" 2>/dev/null || true
  if [[ "$TARGET" == "all" && "$PURGE_DATA" -eq 1 ]]; then
    rm -f "$AC_ROOT/mysql-password" 2>/dev/null || true
  fi
fi

if [[ "$PURGE_DATA" -eq 1 && -d "$AC_DATA" ]]; then
  log "удаляю $AC_DATA"
  rm -rf "$AC_DATA"
fi

if [[ "$TARGET" == "all" ]]; then
  pkill -TERM -x worldserver 2>/dev/null || true
  pkill -TERM -x authserver 2>/dev/null || true
  sleep 1
  pkill -KILL -x worldserver 2>/dev/null || true
  pkill -KILL -x authserver 2>/dev/null || true
fi

echo
log "готово"
echo "Ставить заново: ./scripts/install.sh <вариант>"
