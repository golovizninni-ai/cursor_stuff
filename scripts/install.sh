#!/usr/bin/env bash
# Полная установка одного варианта: deps → clone → build → configure
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VARIANT="${1:-}"
[[ -n "$VARIANT" ]] || { echo "usage: $0 playerbots|npcbots|lonewolf" >&2; exit 2; }
"$SCRIPT_DIR/01-deps.sh"
"$SCRIPT_DIR/02-clone.sh" "$VARIANT"
"$SCRIPT_DIR/03-build.sh" "$VARIANT"
"$SCRIPT_DIR/04-configure.sh" "$VARIANT"
echo
echo "Дальше:"
echo "  1) Положите data в \$HOME/azerothcore-data (см. desktop/ для Buzzit)"
echo "  2) tmux new -s ac ; $HOME/azerothcore-servers/$VARIANT/dist/bin/worldserver"
echo "  3) После импорта SQL: account create ИМЯ ПАРОЛЬ ; account set gmlevel ИМЯ 3 -1"
echo "  4) scripts/set-realm-address.sh $VARIANT <IP_ВМ>"
echo "  5) scripts/setup-ahbot.sh $VARIANT <account_id> <char_guid>"
