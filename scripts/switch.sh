#!/usr/bin/env bash
# Переключить активный вариант: стоп текущего → старт другого.
# Персонажи/мир у каждого варианта свои; аккаунты и IP реалма синхронизируются.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

TO="${1:-}"
[[ -n "$TO" ]] || die "usage: $0 playerbots|npcbots|lonewolf

Переключает уже установленный вариант (бинарники + systemd).
Если ещё не ставили: scripts/install.sh <вариант>"

variant_paths "$TO"
variant_installed "$TO" || die "вариант $TO не установлен.
Сначала: scripts/install.sh $TO
Сейчас стоят: $(list_installed_variants | tr '\n' ' ' || echo «ничего»)"

FROM="$(read_active_variant || true)"
if [[ -n "$FROM" && "$FROM" != "$TO" ]]; then
  log "синхронизация аккаунтов / realm IP: $FROM → $TO"
  sync_accounts_between "$FROM" "$TO" || true
fi

# подтянуть общий IP, если в shared есть, а в БД ещё 127.0.0.1
addr="$(read_shared_realm_address || true)"
if [[ -n "$addr" ]]; then
  ensure_mysql_password
  variant_paths "$TO"
  mysql_acore "${DB_PREFIX}_auth" -e \
    "UPDATE realmlist SET address='${addr}', localAddress='${addr}' WHERE id=1;" 2>/dev/null || true
fi

log "запуск $TO"
exec "$SCRIPT_DIR/start.sh" "$TO"
