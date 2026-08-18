#!/usr/bin/env bash
# Прописать IP реалма, чтобы клиенты друзей подключались не на 127.0.0.1
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

VARIANT="${1:-}"
ADDR="${2:-}"
[[ -n "$VARIANT" && -n "$ADDR" ]] || die "usage: $0 playerbots|npcbots|lonewolf <IP_или_DNS>"
variant_paths "$VARIANT"
MODE="$(read_install_mode "$VARIANT")"

if [[ "$MODE" == "docker" ]]; then
  docker_mysql acore_auth <<SQL
UPDATE realmlist SET address='${ADDR}', localAddress='${ADDR}' WHERE id=1;
SELECT id, name, address, port FROM realmlist;
SQL
else
  ensure_mysql_password
  mysql_acore "${DB_PREFIX}_auth" <<SQL
UPDATE realmlist SET address='${ADDR}', localAddress='${ADDR}' WHERE id=1;
SELECT id, name, address, port FROM realmlist;
SQL
fi
log "realmlist.address = $ADDR"
log "Клиенты: Data/ruRU/realmlist.wtf → set realmlist $ADDR"
