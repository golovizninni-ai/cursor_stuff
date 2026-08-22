#!/bin/bash
set -euo pipefail

MARKER_BEGIN="# BEGIN 8bitdo-hdr-nudge"
MARKER_END="# END 8bitdo-hdr-nudge"

if [[ "$(id -u)" -eq 0 && -n "${SUDO_USER:-}" ]]; then
  REAL_USER="$SUDO_USER"
  USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
  USER_UID="$(id -u "$SUDO_USER")"
else
  REAL_USER="$USER"
  USER_HOME="$HOME"
  USER_UID="$(id -u)"
fi
RUNTIME_DIR="/run/user/${USER_UID}"

run_user() {
  if [[ "$(id -u)" -eq 0 ]]; then
    sudo -u "$REAL_USER" -H \
      env HOME="$USER_HOME" XDG_RUNTIME_DIR="$RUNTIME_DIR" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=${RUNTIME_DIR}/bus" \
      "$@"
  else
    "$@"
  fi
}

run_user systemctl --user disable --now 8bitdo-hdr-nudge.service 2>/dev/null || true
rm -f "${USER_HOME}/.config/systemd/user/8bitdo-hdr-nudge.service"
run_user systemctl --user daemon-reload 2>/dev/null || true

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
  fi
}

for client in steam ogui-steam; do
  strip_marker_block "${USER_HOME}/.config/gamescope-session-plus/sessions.d/$client"
done

rm -f /usr/local/bin/8bitdo-hdr-nudge.sh \
      /usr/local/bin/8bitdo-hdr-nudge-daemon.sh \
      /usr/local/bin/8bitdo-hdr-toggle.py \
      "${USER_HOME}/.local/bin/8bitdo-hdr-nudge.sh" \
      "${USER_HOME}/.local/bin/8bitdo-hdr-nudge-daemon.sh" \
      "${USER_HOME}/.local/bin/8bitdo-hdr-toggle.py"

echo "Removed HDR nudge daemon + hooks."
echo "Config left: ~/.config/environment.d/20-8bitdo-hdr.conf"
echo "linger не трогаем (loginctl disable-linger $REAL_USER — по желанию)."
