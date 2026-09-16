#!/usr/bin/env bash
# Полная очистка варианта(ов): Docker + native + systemd + процессы + БД.
# Не трогает compose-проекты *arr / Sonarr / Radarr.
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
  --purge-data        удалить и \$AC_DATA (карты/dbc; общие для native)
  --keep-data         оставить \$AC_DATA (по умолчанию)
  --keep-db           не DROP native MySQL баз (ac_pb_*/ac_nb_*/ac_lw_*)
  --keep-images       не удалять docker-образы проекта
  -h, --help          эта справка

Примеры:
  $0 -y lonewolf
  $0 -y all --purge-data
EOF
}

YES=0
PURGE_DATA=0
KEEP_DB=0
KEEP_IMAGES=0
TARGET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes) YES=1; shift ;;
    --purge-data) PURGE_DATA=1; shift ;;
    --keep-data) PURGE_DATA=0; shift ;;
    --keep-db) KEEP_DB=1; shift ;;
    --keep-images) KEEP_IMAGES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    all|playerbots|npcbots|lonewolf)
      [[ -z "$TARGET" ]] || die "укажите только один вариант или all"
      TARGET="$1"
      shift
      ;;
    -*)
      die "неизвестная опция: $1 (см. --help)"
      ;;
    *)
      die "неизвестный аргумент: $1 (см. --help)"
      ;;
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
    echo "  - вариант $v: процессы, systemd, docker (контейнеры+volume), каталог $AC_ROOT/$v"
  done
  [[ "$KEEP_DB" -eq 0 ]] && echo "  - native MySQL БД префиксов варианта (если MySQL на хосте)"
  [[ "$PURGE_DATA" -eq 1 ]] && echo "  - клиентские data: $AC_DATA"
  [[ "$KEEP_IMAGES" -eq 0 ]] && echo "  - docker-образы проекта ac-<вариант> (если есть)"
  echo "НЕ трогаем: *arr / Sonarr / Radarr, этот репозиторий (~/azerothcore-deploy)."
  read -r -p "Продолжить? [y/N] " ans
  [[ "$ans" == "y" || "$ans" == "Y" || "$ans" == "yes" ]] || die "отменено"
}

# Остановить и убрать systemd-юниты (user и system), даже если install-mode другой.
uninstall_systemd() {
  local v="$1"
  local auth world
  auth="ac-${v}-auth.service"
  world="ac-${v}-world.service"

  if systemctl --user list-unit-files "${auth}" "${world}" &>/dev/null \
    || [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/${world}" ]]; then
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
    $SUDO systemctl reset-failed "$world" "$auth" 2>/dev/null || true
    $SUDO rm -f "/etc/systemd/system/ac-${v}-auth.service" "/etc/systemd/system/ac-${v}-world.service"
    $SUDO systemctl daemon-reload 2>/dev/null || true
  fi
}

# Docker: compose down -v + сирота-контейнеры по имени ac-<variant>-*
uninstall_docker() {
  local v="$1"
  command -v docker >/dev/null 2>&1 || return 0

  local saved_variant="${VARIANT:-}"
  variant_paths "$v"
  VARIANT="$v"

  local proj
  proj="$(compose_project "$v")"

  if [[ -f "$SRC/docker-compose.yml" ]]; then
    log "docker compose down -v ($proj)"
    local files=(-f docker-compose.yml)
    [[ -f "$SRC/docker-compose.override.yml" ]] && files+=(-f docker-compose.override.yml)
    [[ -f "$SRC/docker-compose.ollama.yml" ]] && files+=(-f docker-compose.ollama.yml)
    local rmi_args=()
    [[ "$KEEP_IMAGES" -eq 0 ]] && rmi_args=(--rmi local)
    docker compose --project-name "$proj" --project-directory "$SRC" "${files[@]}" \
      down -v --remove-orphans "${rmi_args[@]}" 2>/dev/null || true
  else
    # compose-файла нет, но проект мог остаться
    docker compose -p "$proj" down -v --remove-orphans 2>/dev/null || true
  fi

  # Сироты по фиксированным container_name из наших override
  local c
  for c in \
    "ac-${v}-worldserver" \
    "ac-${v}-authserver" \
    "ac-${v}-database" \
    "ac-${v}-db-import" \
    "ac-${v}-client-data" \
    "ac-${v}-client-data-init"
  do
    if docker inspect "$c" >/dev/null 2>&1; then
      log "удаляю контейнер-сироту $c"
      docker rm -f "$c" 2>/dev/null || true
    fi
  done

  # Любые контейнеры с именем/меткой проекта
  while read -r id; do
    [[ -n "$id" ]] || continue
    log "удаляю контейнер $id (проект $proj)"
    docker rm -f "$id" 2>/dev/null || true
  done < <(docker ps -aq --filter "label=com.docker.compose.project=${proj}" 2>/dev/null || true)

  while read -r id; do
    [[ -n "$id" ]] || continue
    docker rm -f "$id" 2>/dev/null || true
  done < <(docker ps -aq --filter "name=ac-${v}-" 2>/dev/null || true)

  # Volume проекта (если down -v не снял)
  while read -r vol; do
    [[ -n "$vol" ]] || continue
    log "удаляю volume $vol"
    docker volume rm -f "$vol" 2>/dev/null || true
  done < <(docker volume ls -q --filter "name=${proj}_" 2>/dev/null || true)

  # Образы с тегом варианта (DOCKER_IMAGE_TAG=variant в .env)
  if [[ "$KEEP_IMAGES" -eq 0 ]]; then
    while read -r img; do
      [[ -n "$img" ]] || continue
      log "удаляю образ $img"
      docker rmi -f "$img" 2>/dev/null || true
    done < <(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -E ":${v}$" || true)
  fi

  if [[ -n "$saved_variant" ]]; then
    VARIANT="$saved_variant"
    variant_paths "$saved_variant"
  fi
}

# Native бинарники, запущенные не через systemd (tmux и т.п.)
kill_native_procs() {
  local v="$1"
  variant_paths "$v"
  local pids=""
  # процессы, чей exe лежит в PREFIX варианта
  if [[ -d "$PREFIX/bin" ]]; then
    pids="$(pgrep -f "$PREFIX/bin/(worldserver|authserver)" 2>/dev/null || true)"
  fi
  if [[ -n "$pids" ]]; then
    log "TERM процессы native $v: $pids"
    # shellcheck disable=SC2086
    kill -TERM $pids 2>/dev/null || true
    sleep 2
    # shellcheck disable=SC2086
    kill -KILL $pids 2>/dev/null || true
  fi
}

drop_native_dbs() {
  local v="$1"
  [[ "$KEEP_DB" -eq 0 ]] || return 0
  variant_paths "$v"
  if ! command -v mysql >/dev/null 2>&1; then
    log "MySQL клиента нет — native БД ${DB_PREFIX}_* пропускаю"
    return 0
  fi
  log "DROP DATABASE ${DB_PREFIX}_* (если есть)"
  local db
  for db in \
    "${DB_PREFIX}_auth" \
    "${DB_PREFIX}_world" \
    "${DB_PREFIX}_characters" \
    "${DB_PREFIX}_playerbots"
  do
    $SUDO mysql --protocol=socket -uroot -e "DROP DATABASE IF EXISTS \`${db}\`;" 2>/dev/null \
      || mysql -h127.0.0.1 -uroot -e "DROP DATABASE IF EXISTS \`${db}\`;" 2>/dev/null \
      || true
  done
}

remove_variant_tree() {
  local v="$1"
  if [[ -d "$AC_ROOT/$v" ]]; then
    log "удаляю каталог $AC_ROOT/$v"
    rm -rf "$AC_ROOT/$v"
  else
    log "каталога $AC_ROOT/$v нет"
  fi
}

clear_active_if_needed() {
  local active
  active="$(read_active_variant || true)"
  [[ -n "$active" ]] || return 0
  local v
  for v in "${VARIANTS[@]}"; do
    if [[ "$active" == "$v" ]]; then
      rm -f "$(active_variant_file)"
      log "сброшен active-variant ($active)"
      return 0
    fi
  done
}

# Если сносим всё и остались только маркеры — подчистить корень.
cleanup_ac_root_if_empty() {
  local left=0
  local v
  for v in playerbots npcbots lonewolf; do
    [[ -e "$AC_ROOT/$v" ]] && left=1
  done
  if [[ "$left" -eq 0 ]]; then
    rm -f "$(active_variant_file)" 2>/dev/null || true
    if [[ "$TARGET" == "all" ]]; then
      # mysql-password оставляем, чтобы повторный install не сменил пароль случайно —
      # но при --purge-data убираем и его вместе с data
      if [[ "$PURGE_DATA" -eq 1 ]]; then
        rm -f "$AC_ROOT/mysql-password" 2>/dev/null || true
      fi
      # пустой корень без вариантов
      if [[ -d "$AC_ROOT" ]] && [[ -z "$(find "$AC_ROOT" -mindepth 1 -maxdepth 1 2>/dev/null | head -1)" ]]; then
        rmdir "$AC_ROOT" 2>/dev/null || true
      fi
    fi
  fi
}

purge_client_data() {
  [[ "$PURGE_DATA" -eq 1 ]] || return 0
  if [[ -d "$AC_DATA" ]]; then
    log "удаляю клиентские data $AC_DATA"
    rm -rf "$AC_DATA"
  fi
}

# --- main ---
confirm

for v in "${VARIANTS[@]}"; do
  echo
  log "=== uninstall $v ==="
  # Порядок: сервисы → docker → процессы → БД → файлы
  # Чистим ОБА режима: после оборванной установки могут остаться и юниты, и контейнеры.
  uninstall_systemd "$v"
  uninstall_docker "$v"
  kill_native_procs "$v"
  drop_native_dbs "$v"
  remove_variant_tree "$v"
done

clear_active_if_needed
cleanup_ac_root_if_empty
purge_client_data

# На всякий случай — голые worldserver/authserver, если сносили all
if [[ "$TARGET" == "all" ]]; then
  if pgrep -x worldserver >/dev/null 2>&1 || pgrep -x authserver >/dev/null 2>&1; then
    log "остались worldserver/authserver — TERM"
    pkill -TERM -x worldserver 2>/dev/null || true
    pkill -TERM -x authserver 2>/dev/null || true
    sleep 2
    pkill -KILL -x worldserver 2>/dev/null || true
    pkill -KILL -x authserver 2>/dev/null || true
  fi
fi

echo
log "готово"
echo "Проверка: ./scripts/doctor.sh <вариант>  (или ls $AC_ROOT)"
echo "Ставить заново:"
echo "  ./scripts/install-docker.sh <вариант>"
echo "  ./scripts/install.sh <вариант>"
