#!/usr/bin/env bash
# Базы, конфиги, systemd для варианта.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

VARIANT="${1:-}"
[[ -n "$VARIANT" ]] || die "usage: $0 playerbots|npcbots|lonewolf"
variant_paths "$VARIANT"
ensure_mysql_password
[[ -x "$PREFIX/bin/worldserver" ]] || die "Сначала scripts/03-build.sh $VARIANT"

log "Базы ${DB_PREFIX}_*"
mysql_root <<SQL
CREATE DATABASE IF NOT EXISTS ${DB_PREFIX}_auth DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS ${DB_PREFIX}_world DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS ${DB_PREFIX}_characters DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON ${DB_PREFIX}_auth.* TO '${MYSQL_USER}'@'localhost';
GRANT ALL PRIVILEGES ON ${DB_PREFIX}_world.* TO '${MYSQL_USER}'@'localhost';
GRANT ALL PRIVILEGES ON ${DB_PREFIX}_characters.* TO '${MYSQL_USER}'@'localhost';
GRANT ALL PRIVILEGES ON ${DB_PREFIX}_auth.* TO '${MYSQL_USER}'@'127.0.0.1';
GRANT ALL PRIVILEGES ON ${DB_PREFIX}_world.* TO '${MYSQL_USER}'@'127.0.0.1';
GRANT ALL PRIVILEGES ON ${DB_PREFIX}_characters.* TO '${MYSQL_USER}'@'127.0.0.1';
SQL

if [[ "$VARIANT" == "playerbots" ]]; then
  mysql_root <<SQL
CREATE DATABASE IF NOT EXISTS ${DB_PREFIX}_playerbots DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON ${DB_PREFIX}_playerbots.* TO '${MYSQL_USER}'@'localhost';
GRANT ALL PRIVILEGES ON ${DB_PREFIX}_playerbots.* TO '${MYSQL_USER}'@'127.0.0.1';
SQL
fi
mysql_root -e "FLUSH PRIVILEGES;"

ETC="$PREFIX/etc"
mkdir -p "$ETC/modules" "$AC_DATA" "$PREFIX/logs"

copy_dist() {
  local dist="$1" conf="$2"
  if [[ -f "$dist" && ! -f "$conf" ]]; then
    cp "$dist" "$conf"
  fi
}

copy_dist "$ETC/authserver.conf.dist" "$ETC/authserver.conf"
copy_dist "$ETC/worldserver.conf.dist" "$ETC/worldserver.conf"
[[ -f "$ETC/authserver.conf" ]] || die "нет authserver.conf — сборка не установила etc/"
[[ -f "$ETC/worldserver.conf" ]] || die "нет worldserver.conf"

python3 "$SCRIPT_DIR/apply_overlay.py" "$ETC/authserver.conf" "$REPO_ROOT/configs/common/authserver.overlay.conf"
python3 "$SCRIPT_DIR/apply_overlay.py" "$ETC/worldserver.conf" "$REPO_ROOT/configs/common/worldserver.overlay.conf"
python3 "$SCRIPT_DIR/apply_overlay.py" "$ETC/worldserver.conf" "$REPO_ROOT/configs/$VARIANT/worldserver.overlay.conf"

GEN="$(mktemp)"
cat >"$GEN" <<EOF
LoginDatabaseInfo = "127.0.0.1;3306;${MYSQL_USER};${MYSQL_PASS};${DB_PREFIX}_auth"
WorldDatabaseInfo = "127.0.0.1;3306;${MYSQL_USER};${MYSQL_PASS};${DB_PREFIX}_world"
CharacterDatabaseInfo = "127.0.0.1;3306;${MYSQL_USER};${MYSQL_PASS};${DB_PREFIX}_characters"
DataDir = "$AC_DATA"
LogsDir = "$PREFIX/logs"
EOF
python3 "$SCRIPT_DIR/apply_overlay.py" "$ETC/worldserver.conf" "$GEN"
python3 "$SCRIPT_DIR/apply_overlay.py" "$ETC/authserver.conf" "$GEN"

if [[ "$VARIANT" == "playerbots" ]]; then
  cat >"$GEN" <<EOF
PlayerbotsDatabaseInfo = "127.0.0.1;3306;${MYSQL_USER};${MYSQL_PASS};${DB_PREFIX}_playerbots"
EOF
  python3 "$SCRIPT_DIR/apply_overlay.py" "$ETC/worldserver.conf" "$GEN"
fi
rm -f "$GEN"

shopt -s nullglob
for dist in "$ETC/modules/"*.conf.dist "$ETC/"*.conf.dist; do
  [[ -f "$dist" ]] || continue
  conf="${dist%.dist}"
  copy_dist "$dist" "$conf"
done

apply_if_present() {
  local conf="$1" overlay="$2"
  [[ -f "$conf" && -f "$overlay" ]] || return 0
  python3 "$SCRIPT_DIR/apply_overlay.py" "$conf" "$overlay"
}

for conf in "$ETC/modules/"*.conf "$ETC/"playerbots.conf; do
  [[ -f "$conf" ]] || continue
  base="$(basename "$conf")"
  case "$base" in
    playerbots.conf)
      apply_if_present "$conf" "$REPO_ROOT/configs/playerbots/playerbots.overlay.conf"
      ;;
    *[Ii]ndividual*)
      apply_if_present "$conf" "$REPO_ROOT/configs/common/individualProgression.overlay.conf"
      ;;
    *[Aa]uto[Bb]alance*)
      apply_if_present "$conf" "$REPO_ROOT/configs/common/AutoBalance.overlay.conf"
      apply_if_present "$conf" "$REPO_ROOT/configs/$VARIANT/AutoBalance.overlay.conf"
      ;;
    *ahbot*|*ah-bot*|*ah_bot*|*mod_ahbot*)
      apply_if_present "$conf" "$REPO_ROOT/configs/common/mod_ahbot.overlay.conf"
      ;;
  esac
done

REALM_IP="${REALM_ADDRESS:-$(hostname -I 2>/dev/null | awk '{print $1}')}"
REALM_IP="${REALM_IP:-127.0.0.1}"
printf '%s\n' "$REALM_IP" >"$PREFIX/realm-address.hint"
log "Адрес реалма (после первого старта): $REALM_IP"

if [[ "$EUID" -eq 0 ]]; then
  UNIT_DIR="/etc/systemd/system"
  RELOAD=(systemctl daemon-reload)
  WANTED="multi-user.target"
else
  UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
  RELOAD=(systemctl --user daemon-reload)
  WANTED="default.target"
fi
mkdir -p "$UNIT_DIR"

SERVICE_USER=""
if [[ "$EUID" -eq 0 ]]; then
  SERVICE_USER="User=${AC_USER}"
fi
other_auth=""
other_world=""
for v in playerbots npcbots lonewolf; do
  if [[ "$v" != "$VARIANT" ]]; then
    other_auth+="ac-${v}-auth.service "
    other_world+="ac-${v}-world.service "
  fi
done

cat >"$UNIT_DIR/ac-${VARIANT}-auth.service" <<EOF
[Unit]
Description=AzerothCore ${VARIANT} authserver
After=network.target mysql.service mysqld.service
Conflicts=${other_auth}

[Service]
Type=simple
${SERVICE_USER}
WorkingDirectory=${PREFIX}
ExecStart=${PREFIX}/bin/authserver
Restart=on-failure
RestartSec=5
TimeoutStopSec=90
KillSignal=SIGTERM
LimitNOFILE=1048576

[Install]
WantedBy=${WANTED}
EOF

cat >"$UNIT_DIR/ac-${VARIANT}-world.service" <<EOF
[Unit]
Description=AzerothCore ${VARIANT} worldserver
After=network.target mysql.service mysqld.service ac-${VARIANT}-auth.service
Conflicts=${other_world}

[Service]
Type=simple
${SERVICE_USER}
WorkingDirectory=${PREFIX}
ExecStart=${PREFIX}/bin/worldserver
Restart=on-failure
RestartSec=5
TimeoutStopSec=90
KillSignal=SIGTERM
LimitNOFILE=1048576

[Install]
WantedBy=${WANTED}
EOF

"${RELOAD[@]}" || log "systemd reload пропущен — юниты лежат в $UNIT_DIR"

log "Конфиги: $ETC"
log "Клиентские data: $AC_DATA (dbc maps vmaps mmaps cameras)"
log "Первый раз worldserver лучше в tmux (импорт SQL, account create)."
log "Потом: scripts/start.sh ${VARIANT}   и   scripts/stop.sh"
log "Насовсем: scripts/enable-autostart.sh ${VARIANT}"
mkdir -p "$AC_ROOT/$VARIANT"
printf 'native\n' >"$AC_ROOT/$VARIANT/install-mode"
