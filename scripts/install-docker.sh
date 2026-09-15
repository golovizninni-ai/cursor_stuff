#!/usr/bin/env bash
# Установка варианта в Docker (без clang и хостового MySQL).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

VARIANT="${1:-}"
[[ -n "$VARIANT" ]] || die "usage: $0 playerbots|npcbots|lonewolf"
command -v docker >/dev/null || die "нужен docker"
docker compose version >/dev/null || die "нужен плагин docker compose"

"$SCRIPT_DIR/02-clone.sh" "$VARIANT"
variant_paths "$VARIANT"
VARIANT="$VARIANT"

if [[ ! -f "$SRC/docker-compose.yml" ]]; then
  die "в этом форке нет docker-compose.yml — ставьте нативно: scripts/install.sh $VARIANT"
fi

# Освободить 3724/8085/13306 у других вариантов (иначе up падает / world в Restarting)
stop_other_variants "$VARIANT"

UID_NUM="$(id -u)"
GID_NUM="$(id -g)"
ensure_mysql_password
DBPASS="$MYSQL_PASS"

if [[ -f "$SRC/.env" ]]; then
  log "обновляю UID/GID/tag в существующем $SRC/.env (пароль БД не трогаю)"
  sed -i \
    -e "s/^DOCKER_IMAGE_TAG=.*/DOCKER_IMAGE_TAG=${VARIANT}/" \
    -e "s/^DOCKER_USER_ID=.*/DOCKER_USER_ID=${UID_NUM}/" \
    -e "s/^DOCKER_GROUP_ID=.*/DOCKER_GROUP_ID=${GID_NUM}/" \
    "$SRC/.env"
  # если пароль ещё changeme — подставить наш
  if grep -q '^DOCKER_DB_ROOT_PASSWORD=changeme$' "$SRC/.env"; then
    sed -i "s/^DOCKER_DB_ROOT_PASSWORD=.*/DOCKER_DB_ROOT_PASSWORD=${DBPASS}/" "$SRC/.env"
  fi
else
  sed \
    -e "s/^DOCKER_IMAGE_TAG=.*/DOCKER_IMAGE_TAG=${VARIANT}/" \
    -e "s/^DOCKER_DB_ROOT_PASSWORD=.*/DOCKER_DB_ROOT_PASSWORD=${DBPASS}/" \
    -e "s/^DOCKER_USER_ID=.*/DOCKER_USER_ID=${UID_NUM}/" \
    -e "s/^DOCKER_GROUP_ID=.*/DOCKER_GROUP_ID=${GID_NUM}/" \
    "$REPO_ROOT/docker/env.example" >"$SRC/.env"
fi

# mem_limit: playerbots тяжелее; lonewolf/npcbots — ниже, иначе OOM на 8 ГБ ВМ с *arr
MEM_LIMIT="4g"
[[ "$VARIANT" == "playerbots" ]] && MEM_LIMIT="8g"

log "docker-compose.override.yml (mem_limit=$MEM_LIMIT)"
python3 - "$SRC" "$VARIANT" "$MEM_LIMIT" <<'PY'
from pathlib import Path
import sys
_src, variant, mem = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
extra_env = ""
if variant == "playerbots":
    extra_env = """
      AC_AI_PLAYERBOT_ENABLED: "1"
      AC_AI_PLAYERBOT_RANDOM_BOT_AUTOLOGIN: "1"
      AC_AI_PLAYERBOT_MIN_RANDOM_BOTS: "200"
      AC_AI_PLAYERBOT_MAX_RANDOM_BOTS: "200"
      AC_AI_PLAYERBOT_SYNC_LEVEL_WITH_PLAYERS: "1"
      AC_AI_PLAYERBOT_GROUP_INVITATION_PERMISSION: "2"
      AC_AI_PLAYERBOT_ADD_CLASS_COMMAND: "1"
      AC_AI_PLAYERBOT_MAX_ADDED_BOTS: "40"
      AC_PLAYERBOTS_DATABASE_INFO: "ac-database;3306;root;${DOCKER_DB_ROOT_PASSWORD};acore_playerbots"
"""
elif variant == "npcbots":
    extra_env = """
      AC_NPC_BOT_ENABLE: "1"
      AC_NPC_BOT_ENABLE_DUNGEON: "1"
      AC_NPC_BOT_ENABLE_RAID: "1"
      AC_NPC_BOT_LIMIT_RAID: "0"
      AC_NPC_BOT_MAX_BOTS_PER_ACCOUNT: "4"
      AC_AUTO_BALANCE_COUNT_NPC_BOTS: "1"
"""
else:
    # lonewolf: AllowTwoSide через conf overlay после старта
    extra_env = ""

# Важно: НЕ ставить AC_UPDATES_ENABLE_DATABASES=7 на world.
# В официальном Docker world = 0, миграции делает ac-db-import.
# Updates=7 на world → повторный SQL → crash loop (Restarting).
text = f"""services:
  ac-database:
    container_name: ac-{variant}-database
    restart: unless-stopped

  ac-db-import:
    container_name: ac-{variant}-db-import
    volumes:
      - ./modules:/azerothcore/modules:ro

  ac-client-data-init:
    container_name: ac-{variant}-client-data

  ac-worldserver:
    container_name: ac-{variant}-worldserver
    restart: unless-stopped
    stdin_open: true
    tty: true
    mem_limit: {mem}
    volumes:
      - ./modules:/azerothcore/modules:ro
    environment:
      AC_REALM_ZONE: "12"
      AC_DECLINED_NAMES: "1"
      AC_DBC_LOCALE: "0"
      AC_SUPPORTED_LOCALES: "0,8"
      AC_ENABLE_PLAYER_SETTINGS: "1"
      AC_DBC_ENFORCE_ITEM_ATTRIBUTES: "0"
      AC_MAX_PRIMARY_TRADE_SKILL: "11"
      AC_MAP_UPDATE_THREADS: "4"
      AC_SOAP_ENABLED: "0"
      AC_BIND_IP: "0.0.0.0"
      AC_WORLD_SERVER_PORT: "8085"
      AC_AUTO_BALANCE_ENABLE_GLOBAL: "1"
      AC_AUTO_BALANCE_MIN_PLAYERS: "1"
      AC_AUCTION_HOUSE_BOT_ENABLE_SELLER: "0"
      AC_AUCTION_HOUSE_BOT_ENABLE_BUYER: "0"
{extra_env}

  ac-authserver:
    container_name: ac-{variant}-authserver
    restart: unless-stopped
    environment:
      AC_BIND_IP: "0.0.0.0"
      AC_REALM_SERVER_PORT: "3724"
"""
(_src / "docker-compose.override.yml").write_text(text)
print("wrote", _src / "docker-compose.override.yml")
PY

if [[ "$VARIANT" == "playerbots" ]]; then
  mkdir -p "$SRC/data/sql/custom/db_characters" "$SRC/data/sql/custom/db_world"
  shopt -s nullglob
  for f in \
    "$SRC/modules/mod-playerbots/data/sql/characters/base/"*.sql \
    "$SRC/modules/mod-playerbots/sql/characters/base/"*.sql
  do
    cp -n "$f" "$SRC/data/sql/custom/db_characters/" || true
  done
  for f in \
    "$SRC/modules/mod-playerbots/data/sql/world/base/"*.sql \
    "$SRC/modules/mod-playerbots/sql/world/base/"*.sql
  do
    cp -n "$f" "$SRC/data/sql/custom/db_world/" || true
  done
fi

log "сборка образов (долго). *arr не трогаем — другой compose-проект"
dc up -d --build

if [[ "$VARIANT" == "playerbots" ]]; then
  load_docker_env
  # БД может ещё стартовать
  for _ in $(seq 1 60); do
    if docker exec "$(docker_db_container "$VARIANT")" \
      mysqladmin ping -uroot -p"${DOCKER_DB_ROOT_PASSWORD:-password}" --silent 2>/dev/null; then
      break
    fi
    sleep 2
  done
  docker exec "$(docker_db_container "$VARIANT")" \
    mysql -uroot -p"${DOCKER_DB_ROOT_PASSWORD:-password}" \
    -e "CREATE DATABASE IF NOT EXISTS acore_playerbots;" || true
fi

log "ждём первый boot (client-data + db-import + world)…"
wait_docker_ready 300

log "применяем configs/*.overlay.conf"
"$SCRIPT_DIR/docker-apply-overlays.sh" "$VARIANT"
dc restart ac-worldserver ac-authserver
wait_docker_ready 180

write_install_mode "$VARIANT" docker
write_active_variant "$VARIANT"

log "режим docker записан в $AC_ROOT/$VARIANT/install-mode"
echo
echo "Готово. Дальше:"
echo "  1) docker attach $(docker_world_container "$VARIANT")"
echo "     account create ИМЯ ПАРОЛЬ"
echo "     account set gmlevel ИМЯ 3 -1"
echo "     отцепиться: Ctrl+P Ctrl+Q  (не Ctrl+C)"
echo "  2) scripts/set-realm-address.sh $VARIANT <IP_ВМ>"
echo "  3) scripts/start.sh / stop.sh / status.sh"
echo "Документация: docs/install-docker.md  README.md"
[[ "$VARIANT" == "playerbots" ]] && echo "Опция чата ботов: scripts/enable-ollama-chat.sh playerbots"
