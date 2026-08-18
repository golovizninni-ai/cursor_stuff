#!/usr/bin/env bash
# Общие функции установки AzerothCore.
set -euo pipefail

AC_ROOT="${AC_ROOT:-$HOME/azerothcore-servers}"
AC_DATA="${AC_DATA:-$HOME/azerothcore-data}"
AC_USER="${AC_USER:-${SUDO_USER:-$(id -un)}}"
MYSQL_USER="${MYSQL_USER:-acore}"
JOBS="${JOBS:-$(nproc)}"

SUDO=""
if [[ "${EUID}" -ne 0 ]]; then
  SUDO="sudo"
fi

log() { printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
die() { printf 'ОШИБКА: %s\n' "$*" >&2; exit 1; }

variant_paths() {
  local variant="$1"
  SRC="$AC_ROOT/$variant/src"
  PREFIX="$AC_ROOT/$variant/dist"
  BUILD="$AC_ROOT/$variant/src/build"
  case "$variant" in
    playerbots) DB_PREFIX="ac_pb" ;;
    npcbots)    DB_PREFIX="ac_nb" ;;
    lonewolf)   DB_PREFIX="ac_lw" ;;
    *) die "Неизвестный вариант: $variant (playerbots|npcbots|lonewolf)" ;;
  esac
}

ensure_mysql_password() {
  local pwfile="$AC_ROOT/mysql-password"
  mkdir -p "$AC_ROOT"
  if [[ ! -f "$pwfile" ]]; then
    umask 077
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24 >"$pwfile"
    echo >>"$pwfile"
  fi
  MYSQL_PASS="$(tr -d '\n' <"$pwfile")"
}

mysql_root() {
  $SUDO mysql --protocol=socket -uroot "$@"
}

mysql_acore() {
  mysql -h127.0.0.1 -u"$MYSQL_USER" -p"$MYSQL_PASS" "$@"
}

require_variant() {
  local variant="${1:-}"
  [[ -n "$variant" ]] || die "usage: $0 playerbots|npcbots|lonewolf"
  variant_paths "$variant"
}

active_variant_file() {
  echo "$AC_ROOT/active-variant"
}

read_active_variant() {
  local f
  f="$(active_variant_file)"
  if [[ -f "$f" ]]; then
    cat "$f"
  fi
}

write_active_variant() {
  mkdir -p "$AC_ROOT"
  printf '%s\n' "$1" >"$(active_variant_file)"
}

resolve_variant() {
  local variant="${1:-}"
  if [[ -z "$variant" ]]; then
    variant="$(read_active_variant || true)"
  fi
  [[ -n "$variant" ]] || die "укажите вариант: playerbots|npcbots|lonewolf (или сначала scripts/start.sh <вариант>)"
  variant_paths "$variant"
  VARIANT="$variant"
}

systemd_for_variant() {
  local variant="$1"
  local user_unit="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/ac-${variant}-world.service"
  local sys_unit="/etc/systemd/system/ac-${variant}-world.service"
  if [[ "${EUID}" -eq 0 && -f "$sys_unit" ]]; then
    SYSTEMCTL=(systemctl)
    UNIT_SCOPE="system"
  elif [[ -f "$user_unit" ]]; then
    SYSTEMCTL=(systemctl --user)
    UNIT_SCOPE="user"
  elif [[ -f "$sys_unit" ]]; then
    if [[ "${EUID}" -eq 0 ]]; then
      SYSTEMCTL=(systemctl)
    else
      SYSTEMCTL=(sudo systemctl)
    fi
    UNIT_SCOPE="system"
  else
    die "нет systemd-юнита ac-${variant}-world. Сначала: scripts/04-configure.sh ${variant}"
  fi
}

sc() {
  "${SYSTEMCTL[@]}" "$@"
}

auth_unit() { echo "ac-${1}-auth.service"; }
world_unit() { echo "ac-${1}-world.service"; }

manual_ac_running() {
  pgrep -x worldserver >/dev/null 2>&1 || pgrep -x authserver >/dev/null 2>&1
}

install_mode_file() {
  echo "$AC_ROOT/$1/install-mode"
}

read_install_mode() {
  local v="${1:-${VARIANT:-}}"
  local f
  f="$(install_mode_file "$v")"
  if [[ -f "$f" ]]; then
    tr -d '[:space:]' <"$f"
  else
    echo native
  fi
}

write_install_mode() {
  mkdir -p "$AC_ROOT/$1"
  printf '%s\n' "$2" >"$(install_mode_file "$1")"
}

compose_project() {
  echo "ac-${1}"
}

dc() {
  local files=()
  [[ -f "$SRC/docker-compose.yml" ]] && files+=(-f docker-compose.yml)
  [[ -f "$SRC/docker-compose.override.yml" ]] && files+=(-f docker-compose.override.yml)
  [[ -f "$SRC/docker-compose.ollama.yml" ]] && files+=(-f docker-compose.ollama.yml)
  docker compose --project-name "$(compose_project "$VARIANT")" --project-directory "$SRC" "${files[@]}" "$@"
}

docker_world_container() { echo "ac-${1}-worldserver"; }
docker_auth_container() { echo "ac-${1}-authserver"; }
docker_db_container() { echo "ac-${1}-database"; }

load_docker_env() {
  [[ -f "$SRC/.env" ]] || return 0
  set -a
  # shellcheck disable=SC1091
  source "$SRC/.env"
  set +a
}

docker_mysql() {
  load_docker_env
  local pass="${DOCKER_DB_ROOT_PASSWORD:-password}"
  docker exec -i "$(docker_db_container "$VARIANT")" mysql -uroot -p"${pass}" "$@"
}

stop_variant_stack() {
  local v="$1"
  local mode
  mode="$(read_install_mode "$v")"
  local saved_variant="${VARIANT:-}"
  variant_paths "$v"
  VARIANT="$v"
  if [[ "$mode" == "docker" ]]; then
    if [[ -f "$SRC/docker-compose.yml" ]] && command -v docker >/dev/null; then
      docker compose --project-name "$(compose_project "$v")" --project-directory "$SRC" stop ac-worldserver ac-authserver 2>/dev/null || true
    fi
  else
    if [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/ac-${v}-world.service" ]] || [[ -f "/etc/systemd/system/ac-${v}-world.service" ]]; then
      systemd_for_variant "$v"
      sc stop "$(world_unit "$v")" "$(auth_unit "$v")" 2>/dev/null || true
    fi
  fi
  if [[ -n "$saved_variant" ]]; then
    VARIANT="$saved_variant"
    variant_paths "$saved_variant"
  fi
}

stop_other_variants() {
  local current="$1"
  local v
  for v in playerbots npcbots lonewolf; do
    [[ "$v" != "$current" ]] || continue
    [[ -d "$AC_ROOT/$v" ]] || continue
    stop_variant_stack "$v"
  done
}

