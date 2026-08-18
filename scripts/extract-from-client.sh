#!/usr/bin/env bash
# Извлечение maps/vmaps/mmaps/dbc на Ubuntu из копии клиента 3.3.5a.
# Серверные DBC лучше enUS (playerbots). Maps не зависят от языка.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

CLIENT="${1:-}"
VARIANT="${2:-playerbots}"
[[ -n "$CLIENT" && -d "$CLIENT" ]] || die "usage: $0 /path/to/WoW-3.3.5a [variant]"
variant_paths "$VARIANT"
BIN="$PREFIX/bin"
[[ -x "$BIN/mapextractor" ]] || die "нет mapextractor — соберите вариант с TOOLS_BUILD=all"

WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

log "копирую инструменты к клиенту"
cp -a "$BIN/mapextractor" "$BIN/vmap4extractor" "$BIN/vmap4assembler" "$BIN/mmaps_generator" "$CLIENT/" 2>/dev/null || \
  cp -a "$BIN/"mapextractor "$BIN/"vmap4extractor "$BIN/"vmap4assembler "$BIN/"mmaps_generator "$CLIENT/"

(
  cd "$CLIENT"
  log "mapextractor"
  ./mapextractor
  log "vmaps"
  ./vmap4extractor
  mkdir -p vmaps
  ./vmap4assembler Buildings vmaps
  log "mmaps (долго)"
  mkdir -p mmaps
  ./mmaps_generator
)

mkdir -p "$AC_DATA"
for d in dbc maps vmaps mmaps cameras; do
  if [[ -d "$CLIENT/$d" ]]; then
    rsync -a "$CLIENT/$d/" "$AC_DATA/$d/"
    log "скопирован $d"
  fi
done
log "готово: $AC_DATA"
log "Для playerbots серверные DBC должны быть enUS. Если извлекли из ruRU — подмените папку dbc архивом enUS AC Data."
