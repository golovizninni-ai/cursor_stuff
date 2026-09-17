#!/usr/bin/env bash
# Общие функции нативной установки AzerothCore (без Docker).
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

ALL_VARIANTS=(playerbots npcbots lonewolf)

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

shared_dir() {
  echo "$AC_ROOT/shared"
}

read_active_variant() {
  local f
  f="$(active_variant_file)"
  if [[ -f "$f" ]]; then
    tr -d '[:space:]' <"$f"
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
  [[ -n "$variant" ]] || die "укажите вариант: playerbots|npcbots|lonewolf
  (или сначала: scripts/install.sh <вариант> / scripts/start.sh <вариант>)"
  variant_paths "$variant"
  VARIANT="$variant"
}

native_binaries_ok() {
  local variant="${1:-${VARIANT:-}}"
  variant_paths "$variant"
  [[ -x "$PREFIX/bin/authserver" && -x "$PREFIX/bin/worldserver" ]]
}

variant_installed() {
  local variant="$1"
  native_binaries_ok "$variant" || return 1
  local user_unit="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/ac-${variant}-world.service"
  local sys_unit="/etc/systemd/system/ac-${variant}-world.service"
  [[ -f "$user_unit" || -f "$sys_unit" ]]
}

list_installed_variants() {
  local v
  for v in "${ALL_VARIANTS[@]}"; do
    if variant_installed "$v"; then
      echo "$v"
    fi
  done
}

require_native_binaries() {
  local variant="${1:-${VARIANT:-}}"
  variant_paths "$variant"
  if native_binaries_ok "$variant"; then
    return 0
  fi
  die "нет исполняемых $PREFIX/bin/{authserver,worldserver}.
Сначала доведите установку: scripts/install.sh $variant
Уже стоят: $(list_installed_variants | tr '\n' ' ' || echo «ничего»)"
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
    die "нет systemd-юнита ac-${variant}-world.
Сначала: scripts/install.sh ${variant}
Уже стоят: $(list_installed_variants | tr '\n' ' ' || echo «ничего»)"
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

# Сохранить IP реалма в общий файл (для переноса на другой вариант).
save_shared_realm_address() {
  local addr="$1"
  [[ -n "$addr" ]] || return 0
  mkdir -p "$(shared_dir)"
  printf '%s\n' "$addr" >"$(shared_dir)/realm-address"
}

read_shared_realm_address() {
  local f
  f="$(shared_dir)/realm-address"
  if [[ -f "$f" ]]; then
    tr -d '[:space:]' <"$f"
  fi
}

# Скопировать аккаунты + IP реалма из from → to (оба auth DB уже с таблицами).
sync_accounts_between() {
  local from="$1" to="$2"
  [[ "$from" != "$to" ]] || return 0
  local from_prefix to_prefix
  case "$from" in
    playerbots) from_prefix=ac_pb ;;
    npcbots) from_prefix=ac_nb ;;
    lonewolf) from_prefix=ac_lw ;;
    *) return 0 ;;
  esac
  case "$to" in
    playerbots) to_prefix=ac_pb ;;
    npcbots) to_prefix=ac_nb ;;
    lonewolf) to_prefix=ac_lw ;;
    *) return 0 ;;
  esac

  ensure_mysql_password
  local has_from has_to
  has_from="$(mysql_acore -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${from_prefix}_auth' AND table_name='account';" 2>/dev/null || echo 0)"
  has_to="$(mysql_acore -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${to_prefix}_auth' AND table_name='account';" 2>/dev/null || echo 0)"
  if [[ "$has_from" != "1" || "$has_to" != "1" ]]; then
    log "аккаунты не копирую: у одного из вариантов ещё не было первого запуска worldserver"
    return 0
  fi

  log "копирую account / account_access: $from → $to"
  local dump
  dump="$(mktemp)"
  mysqldump -h127.0.0.1 -u"$MYSQL_USER" -p"$MYSQL_PASS" \
    --no-create-info --skip-triggers --compact \
    "${from_prefix}_auth" account account_access >"$dump" 2>/dev/null || {
    rm -f "$dump"
    log "предупреждение: mysqldump аккаунтов не удался"
    return 0
  }
  mysql_acore "${to_prefix}_auth" -e "DELETE FROM account_access; DELETE FROM account;" 2>/dev/null || true
  mysql_acore "${to_prefix}_auth" <"$dump" 2>/dev/null || log "предупреждение: импорт аккаунтов частично не удался"
  rm -f "$dump"

  local addr
  addr="$(mysql_acore -N -e "SELECT address FROM ${from_prefix}_auth.realmlist WHERE id=1 LIMIT 1;" 2>/dev/null || true)"
  if [[ -z "$addr" ]]; then
    addr="$(read_shared_realm_address || true)"
  fi
  if [[ -n "$addr" ]]; then
    mysql_acore "${to_prefix}_auth" -e "UPDATE realmlist SET address='${addr}', localAddress='${addr}' WHERE id=1;" 2>/dev/null || true
    save_shared_realm_address "$addr"
    log "realmlist.address = $addr (скопирован)"
  fi
}

# Перенести общие настройки с предыдущего активного варианта на новый после install.
carry_over_shared_settings() {
  local to="$1"
  local from="${2:-}"
  if [[ -z "$from" ]]; then
    from="$(read_active_variant || true)"
  fi
  mkdir -p "$(shared_dir)"

  local addr
  addr="$(read_shared_realm_address || true)"
  if [[ -z "$addr" && -n "$from" && "$from" != "$to" ]]; then
    variant_paths "$from"
    if [[ -f "$PREFIX/realm-address.hint" ]]; then
      addr="$(tr -d '[:space:]' <"$PREFIX/realm-address.hint")"
    fi
  fi
  if [[ -n "$addr" ]]; then
    save_shared_realm_address "$addr"
    variant_paths "$to"
    printf '%s\n' "$addr" >"$PREFIX/realm-address.hint"
    log "общий IP реалма сохранён: $addr (примените после первого старта: scripts/set-realm-address.sh $to $addr)"
  fi

  if [[ -n "$from" && "$from" != "$to" ]]; then
    sync_accounts_between "$from" "$to" || true
  fi
}

stop_variant_stack() {
  local v="$1"
  local saved_variant="${VARIANT:-}"
  variant_paths "$v"
  VARIANT="$v"
  if [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/ac-${v}-world.service" ]] \
    || [[ -f "/etc/systemd/system/ac-${v}-world.service" ]]; then
    if systemd_for_variant "$v" 2>/dev/null; then
      log "стоп systemd $v"
      sc stop "$(world_unit "$v")" "$(auth_unit "$v")" 2>/dev/null || true
    fi
  fi
  # процессы из dist этого варианта
  if [[ -d "$PREFIX/bin" ]]; then
    pgrep -f "$PREFIX/bin/(worldserver|authserver)" >/dev/null 2>&1 && {
      log "TERM native процессы $v"
      pkill -TERM -f "$PREFIX/bin/(worldserver|authserver)" 2>/dev/null || true
      sleep 2
      pkill -KILL -f "$PREFIX/bin/(worldserver|authserver)" 2>/dev/null || true
    } || true
  fi
  if [[ -n "$saved_variant" ]]; then
    VARIANT="$saved_variant"
    variant_paths "$saved_variant"
  fi
}

stop_other_variants() {
  local current="$1"
  local v
  for v in "${ALL_VARIANTS[@]}"; do
    [[ "$v" != "$current" ]] || continue
    [[ -d "$AC_ROOT/$v" ]] || continue
    stop_variant_stack "$v"
  done
}
