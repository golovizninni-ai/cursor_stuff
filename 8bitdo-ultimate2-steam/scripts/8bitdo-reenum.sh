#!/bin/bash
# Краткий USB reset того же порта, когда геймпад появился как 6012 (D-Input).
# Заставляет Steam увидеть «новое» подключение вместо залипшего 6013.
#
# Установка:
#   sudo cp 8bitdo-reenum.sh /usr/local/bin/
#   sudo chmod +x /usr/local/bin/8bitdo-reenum.sh

set -euo pipefail

DEVPATH="${1:-}"
if [[ -z "$DEVPATH" ]]; then
  exit 0
fi

USB_SYS="/sys${DEVPATH}"
STAMP="/run/8bitdo-6012-reset"
now="$(date +%s)"

if [[ -f "$STAMP" ]]; then
  last="$(cat "$STAMP")"
  if (( now - last < 8 )); then
    exit 0
  fi
fi

echo "$now" > "$STAMP"

if [[ -f "${USB_SYS}/authorized" ]]; then
  echo 0 > "${USB_SYS}/authorized"
  sleep 0.3
  echo 1 > "${USB_SYS}/authorized"
fi
