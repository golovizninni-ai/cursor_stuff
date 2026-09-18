#!/usr/bin/env bash
# Синхронизировать пароль acore из ~/azerothcore-servers/mysql-password в MySQL и conf.
# Лечит: Access denied for user 'acore'@'localhost' у playerbots / после переустановок.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

VARIANT="${1:-}"
ensure_mysql_password

log "сброс пароля MySQL пользователя ${MYSQL_USER}"
mysql_root <<SQL
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASS}';
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'127.0.0.1' IDENTIFIED BY '${MYSQL_PASS}';
ALTER USER '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASS}';
ALTER USER '${MYSQL_USER}'@'127.0.0.1' IDENTIFIED BY '${MYSQL_PASS}';
GRANT ALL PRIVILEGES ON \`ac\_%\`.* TO '${MYSQL_USER}'@'localhost';
GRANT ALL PRIVILEGES ON \`ac\_%\`.* TO '${MYSQL_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL

echo "пароль из файла: $AC_ROOT/mysql-password"
echo -n "проверка TCP 127.0.0.1: "
if mysql -h127.0.0.1 -u"$MYSQL_USER" -p"$MYSQL_PASS" -e "SELECT 1;" &>/dev/null; then
  echo OK
else
  die "acore по TCP всё ещё не пускает — смотрите sudo mysql и auth plugin"
fi

if [[ -n "$VARIANT" ]]; then
  variant_paths "$VARIANT"
  [[ -d "$PREFIX/etc" ]] || die "нет $PREFIX/etc — сначала install.sh $VARIANT"
  log "прописываю пароль в conf ($VARIANT)"
  GEN="$(mktemp)"
  cat >"$GEN" <<EOF
LoginDatabaseInfo = "127.0.0.1;3306;${MYSQL_USER};${MYSQL_PASS};${DB_PREFIX}_auth"
WorldDatabaseInfo = "127.0.0.1;3306;${MYSQL_USER};${MYSQL_PASS};${DB_PREFIX}_world"
CharacterDatabaseInfo = "127.0.0.1;3306;${MYSQL_USER};${MYSQL_PASS};${DB_PREFIX}_characters"
EOF
  [[ -f "$PREFIX/etc/worldserver.conf" ]] && python3 "$SCRIPT_DIR/apply_overlay.py" "$PREFIX/etc/worldserver.conf" "$GEN"
  [[ -f "$PREFIX/etc/authserver.conf" ]] && python3 "$SCRIPT_DIR/apply_overlay.py" "$PREFIX/etc/authserver.conf" "$GEN"
  if [[ "$VARIANT" == "playerbots" ]]; then
    cat >"$GEN" <<EOF
PlayerbotsDatabaseInfo = "127.0.0.1;3306;${MYSQL_USER};${MYSQL_PASS};${DB_PREFIX}_playerbots"
EOF
    [[ -f "$PREFIX/etc/worldserver.conf" ]] && python3 "$SCRIPT_DIR/apply_overlay.py" "$PREFIX/etc/worldserver.conf" "$GEN"
    for cand in "$PREFIX/etc/playerbots.conf" "$PREFIX/etc/modules/playerbots.conf"; do
      [[ -f "$cand" ]] || continue
      python3 "$SCRIPT_DIR/apply_overlay.py" "$cand" "$GEN"
      log "обновлён $cand"
    done
    mysql_root <<SQL
CREATE DATABASE IF NOT EXISTS ${DB_PREFIX}_playerbots DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON ${DB_PREFIX}_playerbots.* TO '${MYSQL_USER}'@'localhost';
GRANT ALL PRIVILEGES ON ${DB_PREFIX}_playerbots.* TO '${MYSQL_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL
  fi
  rm -f "$GEN"
  echo "перезапуск: scripts/restart.sh $VARIANT"
else
  echo "чтобы прописать conf варианта: $0 playerbots|npcbots|lonewolf"
fi
