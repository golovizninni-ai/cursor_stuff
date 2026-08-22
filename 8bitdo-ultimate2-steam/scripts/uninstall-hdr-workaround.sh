#!/bin/bash
# Снять HDR nudge hooks (sessions.d + binaries).
set -euo pipefail

MARKER_BEGIN="# BEGIN 8bitdo-hdr-nudge"
MARKER_END="# END 8bitdo-hdr-nudge"

if [[ "$(id -u)" -eq 0 && -n "${SUDO_USER:-}" ]]; then
  USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
  USER_HOME="$HOME"
fi

strip_marker_block() {
  local target="$1"
  [[ -f "$target" ]] || return 0
  if grep -qF "$MARKER_BEGIN" "$target"; then
    local tmp
    tmp="$(mktemp)"
    awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '
      $0 == b {skip=1; next}
      $0 == e {skip=0; next}
      !skip {print}
    ' "$target" >"$tmp"
    if [[ ! -s "$tmp" ]] || ! grep -q '[^[:space:]]' "$tmp"; then
      rm -f "$target" "$tmp"
    else
      mv "$tmp" "$target"
    fi
    return 0
  fi
  # старая установка без маркеров: файл только наш snippet
  if grep -q "8bitdo-hdr-nudge" "$target" && ! grep -qvE '^(#|$|[[:space:]])' "$target"; then
    # слишком грубо — лучше: если весь файл совпадает по ключевым строкам
    if grep -q "post_gamescope_start" "$target" && grep -q "8bitdo-hdr-nudge" "$target" \
       && ! grep -qE 'GAMESCOPECMD|STEAMCMD|CLIENTCMD|OUTPUT_CONNECTOR' "$target"; then
      rm -f "$target"
    fi
  fi
}

for client in steam ogui-steam; do
  strip_marker_block "${USER_HOME}/.config/gamescope-session-plus/sessions.d/$client"
done

rm -f /usr/local/bin/8bitdo-hdr-nudge.sh \
      "${USER_HOME}/.local/bin/8bitdo-hdr-nudge.sh"

echo "Removed HDR nudge hooks."
echo "Config left: ~/.config/environment.d/20-8bitdo-hdr.conf (удалите вручную при желании)."
echo "Force Composite в Steam Developer options тоже вручную, если включали."
