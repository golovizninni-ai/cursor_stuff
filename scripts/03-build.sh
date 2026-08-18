#!/usr/bin/env bash
# cmake + сборка + install
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

VARIANT="${1:-}"
[[ -n "$VARIANT" ]] || die "usage: $0 playerbots|npcbots|lonewolf"
variant_paths "$VARIANT"
[[ -d "$SRC" ]] || die "Сначала scripts/02-clone.sh $VARIANT"

mkdir -p "$BUILD" "$PREFIX"
cd "$BUILD"

log "cmake ($VARIANT, jobs=$JOBS)"
cmake "$SRC" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_C_COMPILER=/usr/bin/clang \
  -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DWITH_WARNINGS=0 \
  -DTOOLS_BUILD=all \
  -DSCRIPTS=static \
  -DMODULES=static

log "сборка"
cmake --build . --config RelWithDebInfo -j"$JOBS"
cmake --install .

log "Бинарники: $PREFIX/bin"
