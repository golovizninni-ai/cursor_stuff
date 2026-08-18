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
