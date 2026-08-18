#!/usr/bin/env bash
# Привязать персонажа-заглушку к AHBot (продавец + покупатель).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

VARIANT="${1:-}"
ACCOUNT_ID="${2:-}"
CHAR_GUID="${3:-}"
[[ -n "$VARIANT" && -n "$ACCOUNT_ID" && -n "$CHAR_GUID" ]] || die "usage: $0 <variant> <account_id> <character_guid>"
variant_paths "$VARIANT"
MODE="$(read_install_mode "$VARIANT")"
if [[ "$MODE" == "docker" ]]; then
  ETC="$SRC/env/dist/etc"
else
  ETC="$PREFIX/etc"
fi
overlay="$(mktemp)"
cat >"$overlay" <<EOF
AuctionHouseBot.EnableSeller = 1
AuctionHouseBot.EnableBuyer = 1
AuctionHouseBot.Account = ${ACCOUNT_ID}
AuctionHouseBot.GUID = ${CHAR_GUID}
AuctionHouseBot.VendorTradeGoods = 1
AuctionHouseBot.LootTradeGoods = 1
AuctionHouseBot.ProfessionItems = 1
AuctionHouseBot.OtherTradeGoods = 1
EOF

shopt -s nullglob
found=0
for conf in "$ETC/modules/"*ahbot*.conf "$ETC/modules/"*ah-bot*.conf "$ETC/modules/"*ah_bot*.conf; do
  python3 "$SCRIPT_DIR/apply_overlay.py" "$conf" "$overlay"
  found=1
  log "обновлён $conf"
done
rm -f "$overlay"
[[ "$found" -eq 1 ]] || die "не найден mod_ahbot.conf — для docker дождитесь первого старта (etc/modules), для native: 04-configure"
log "Перезапустите мир: scripts/restart.sh $VARIANT. Этим персонажем в игру не заходите."
