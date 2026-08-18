#!/usr/bin/env bash
# Bazzite/Fedora → Ubuntu-ВМ: залить каталог клиента 3.3.5a для экстракта карт.
set -euo pipefail

usage() {
  echo "usage: $0 --wow-dir DIR --server USER@HOST [--remote-dir /home/USER/wow-client]" >&2
  exit 2
}

WOW_DIR=""
SERVER=""
REMOTE_DIR="/home/ubuntu/wow-client"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wow-dir) WOW_DIR="$2"; shift 2 ;;
    --server) SERVER="$2"; shift 2 ;;
    --remote-dir) REMOTE_DIR="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
done

[[ -n "$WOW_DIR" && -n "$SERVER" ]] || usage
[[ -d "$WOW_DIR" ]] || { echo "нет каталога: $WOW_DIR" >&2; exit 1; }

if [[ ! -f "$WOW_DIR/Wow.exe" && ! -f "$WOW_DIR/wow.exe" ]]; then
  echo "предупреждение: Wow.exe не найден в $WOW_DIR — это должен быть корень 3.3.5a" >&2
fi

echo "rsync → ${SERVER}:${REMOTE_DIR}"
ssh "$SERVER" "mkdir -p '$REMOTE_DIR'"
rsync -a --info=progress2 --exclude='Cache/' --exclude='Logs/' --exclude='Errors/' \
  "$WOW_DIR/" "${SERVER}:${REMOTE_DIR}/"

cat <<EOF

На ВМ:

  ~/azerothcore-deploy/scripts/extract-from-client.sh ${REMOTE_DIR} playerbots

Серверные dbc лучше enUS. Играть с Bazzite с ruRU клиента.
EOF
