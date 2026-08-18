#!/usr/bin/env bash
# Распаковать архив data с десктопа в \$AC_DATA
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

ARCHIVE="${1:-}"
[[ -n "$ARCHIVE" && -f "$ARCHIVE" ]] || die "usage: $0 /path/to/ac-data.zip|tar.gz"
mkdir -p "$AC_DATA"
case "$ARCHIVE" in
  *.zip) unzip -o "$ARCHIVE" -d "$AC_DATA" ;;
  *.tar.gz|*.tgz) tar -xzf "$ARCHIVE" -C "$AC_DATA" ;;
  *.tar) tar -xf "$ARCHIVE" -C "$AC_DATA" ;;
  *) die "нужен zip или tar.gz" ;;
esac

# если внутри вложенная папка Data/ — поднять
if [[ -d "$AC_DATA/Data/maps" && ! -d "$AC_DATA/maps" ]]; then
  mv "$AC_DATA/Data/"* "$AC_DATA/" || true
fi
for d in dbc maps vmaps mmaps; do
  if [[ ! -d "$AC_DATA/$d" ]]; then
    log "предупреждение: нет $AC_DATA/$d"
  else
    log "ok $d ($(du -sh "$AC_DATA/$d" | awk '{print $1}'))"
  fi
done
log "DataDir = $AC_DATA"
