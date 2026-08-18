#!/usr/bin/env bash
# Клонирование ядра и модулей для варианта playerbots|npcbots|lonewolf
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

VARIANT="${1:-}"
[[ -n "$VARIANT" ]] || die "usage: $0 playerbots|npcbots|lonewolf"
variant_paths "$VARIANT"
mkdir -p "$AC_ROOT/$VARIANT"

clone_or_update() {
  local url="$1" dest="$2" branch="${3:-}"
  if [[ -d "$dest/.git" ]]; then
    log "Обновление $dest"
    git -C "$dest" fetch --depth 1 origin
    if [[ -n "$branch" ]]; then
      git -C "$dest" checkout "$branch"
      git -C "$dest" pull --ff-only origin "$branch" || true
    else
      git -C "$dest" pull --ff-only || true
    fi
  else
    log "Клон $url → $dest"
    if [[ -n "$branch" ]]; then
      git clone --depth 1 --branch "$branch" "$url" "$dest"
    else
      git clone --depth 1 "$url" "$dest"
    fi
  fi
}

case "$VARIANT" in
  playerbots)
    clone_or_update https://github.com/mod-playerbots/azerothcore-wotlk.git "$SRC" Playerbot
    mkdir -p "$SRC/modules"
    clone_or_update https://github.com/mod-playerbots/mod-playerbots.git "$SRC/modules/mod-playerbots" master
    clone_or_update https://github.com/azerothcore/mod-autobalance.git "$SRC/modules/mod-autobalance" master
    ;;
  npcbots)
    clone_or_update https://github.com/trickerer/AzerothCore-wotlk-with-NPCBots.git "$SRC" npcbots_3.3.5
    mkdir -p "$SRC/modules"
    clone_or_update https://github.com/trickerer/mod-autobalance.git "$SRC/modules/mod-autobalance" master
    ;;
  lonewolf)
    clone_or_update https://github.com/azerothcore/azerothcore-wotlk.git "$SRC" master
    mkdir -p "$SRC/modules"
    clone_or_update https://github.com/azerothcore/mod-autobalance.git "$SRC/modules/mod-autobalance" master
    ;;
esac

mkdir -p "$SRC/modules"
clone_or_update https://github.com/ZhengPeiRu21/mod-individual-progression.git "$SRC/modules/mod-individual-progression" master
clone_or_update https://github.com/azerothcore/mod-ah-bot.git "$SRC/modules/mod-ah-bot" master

log "Исходники готовы: $SRC"
