#!/usr/bin/env bash
# Применить configs/*.overlay.conf к Docker etc после первого старта.
# В Docker миграции БД делает ac-db-import; world держит Updates.EnableDatabases=0.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

resolve_variant "${1:-}"
[[ "$(read_install_mode "$VARIANT")" == "docker" ]] || die "не docker-режим: $VARIANT"
ETC="$SRC/env/dist/etc"
[[ -d "$ETC" ]] || die "нет $ETC — сначала поднимите стек (install-docker / start)"

apply_if() {
  local conf="$1" overlay="$2"
  [[ -f "$conf" && -f "$overlay" ]] || return 0
  python3 "$SCRIPT_DIR/apply_overlay.py" "$conf" "$overlay"
  log "overlay → $(basename "$conf") ← $(basename "$overlay")"
}

# Ждём появления worldserver.conf (entrypoint копирует из .dist)
for _ in $(seq 1 60); do
  [[ -f "$ETC/worldserver.conf" ]] && break
  sleep 1
done
[[ -f "$ETC/worldserver.conf" ]] || die "нет $ETC/worldserver.conf"

apply_if "$ETC/worldserver.conf" "$REPO_ROOT/configs/common/worldserver.overlay.conf"
apply_if "$ETC/worldserver.conf" "$REPO_ROOT/configs/$VARIANT/worldserver.overlay.conf"

# Docker: SQL-апдейты только в ac-db-import. Иначе world падает в restart loop.
tmp="$(mktemp)"
printf 'Updates.EnableDatabases = 0\n' >"$tmp"
python3 "$SCRIPT_DIR/apply_overlay.py" "$ETC/worldserver.conf" "$tmp"
rm -f "$tmp"
log "Updates.EnableDatabases = 0 (docker)"

if [[ -f "$ETC/authserver.conf" ]]; then
  apply_if "$ETC/authserver.conf" "$REPO_ROOT/configs/common/authserver.overlay.conf"
fi

shopt -s nullglob
for conf in "$ETC/modules/"*.conf "$ETC/"playerbots.conf; do
  [[ -f "$conf" ]] || continue
  base="$(basename "$conf")"
  case "$base" in
    playerbots.conf)
      apply_if "$conf" "$REPO_ROOT/configs/playerbots/playerbots.overlay.conf"
      if [[ -f "$AC_ROOT/$VARIANT/ollama-chat" ]]; then
        apply_if "$conf" "$REPO_ROOT/configs/playerbots/playerbots-ollama.overlay.conf"
      fi
      ;;
    *ollama*)
      apply_if "$conf" "$REPO_ROOT/configs/playerbots/mod_ollama_chat.overlay.conf"
      ;;
    *[Ii]ndividual*)
      apply_if "$conf" "$REPO_ROOT/configs/common/individualProgression.overlay.conf"
      ;;
    *[Aa]uto[Bb]alance*)
      apply_if "$conf" "$REPO_ROOT/configs/common/AutoBalance.overlay.conf"
      apply_if "$conf" "$REPO_ROOT/configs/$VARIANT/AutoBalance.overlay.conf"
      ;;
    *ahbot*|*ah-bot*|*ah_bot*|*mod_ahbot*)
      apply_if "$conf" "$REPO_ROOT/configs/common/mod_ahbot.overlay.conf"
      ;;
  esac
done

log "Docker overlays применены в $ETC"
