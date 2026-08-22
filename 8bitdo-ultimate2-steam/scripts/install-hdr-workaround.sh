#!/bin/bash
# Обход выбеленного HDR: демон следит за gamescope и делает HDR off→on.
#
#   ./scripts/install-hdr-workaround.sh
#   sudo ./scripts/install-hdr-workaround.sh   # + /usr/local/bin + linger
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MARKER_BEGIN="# BEGIN 8bitdo-hdr-nudge"
MARKER_END="# END 8bitdo-hdr-nudge"

if [[ "$(id -u)" -eq 0 && -n "${SUDO_USER:-}" ]]; then
  REAL_USER="$SUDO_USER"
  USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
  USER_UID="$(id -u "$SUDO_USER")"
else
  REAL_USER="${USER}"
  USER_HOME="$HOME"
  USER_UID="$(id -u)"
fi

SESS_DIR="${USER_HOME}/.config/gamescope-session-plus/sessions.d"
BIN_USER="${USER_HOME}/.local/bin"
UNIT_DIR="${USER_HOME}/.config/systemd/user"
SNIPPET="$ROOT/config/gamescope-session-hdr-nudge.sh"
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

install_bins() {
  mkdir -p "$BIN_USER"
  install -m 0755 "$ROOT/scripts/8bitdo-hdr-nudge.sh" "$BIN_USER/8bitdo-hdr-nudge.sh"
  install -m 0755 "$ROOT/scripts/8bitdo-hdr-nudge-daemon.sh" "$BIN_USER/8bitdo-hdr-nudge-daemon.sh"
  install -m 0755 "$ROOT/scripts/8bitdo-hdr-toggle.py" "$BIN_USER/8bitdo-hdr-toggle.py"
  if [[ "$(id -u)" -eq 0 ]]; then
    install -m 0755 "$ROOT/scripts/8bitdo-hdr-nudge.sh" /usr/local/bin/8bitdo-hdr-nudge.sh
    install -m 0755 "$ROOT/scripts/8bitdo-hdr-nudge-daemon.sh" /usr/local/bin/8bitdo-hdr-nudge-daemon.sh
    install -m 0755 "$ROOT/scripts/8bitdo-hdr-toggle.py" /usr/local/bin/8bitdo-hdr-toggle.py
    chown -R "$REAL_USER:" "$BIN_USER/8bitdo-hdr-nudge.sh" \
      "$BIN_USER/8bitdo-hdr-nudge-daemon.sh" "$BIN_USER/8bitdo-hdr-toggle.py"
  fi
}

merge_session_file() {
  local target="$1"
  mkdir -p "$(dirname "$target")"
  if [[ -f "$target" ]] && grep -qF "$MARKER_BEGIN" "$target"; then
    local tmp
    tmp="$(mktemp)"
    awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '
      $0 == b {skip=1; next}
      $0 == e {skip=0; next}
      !skip {print}
    ' "$target" >"$tmp"
    cat "$SNIPPET" >>"$tmp"
    mv "$tmp" "$target"
  elif [[ -f "$target" ]]; then
    { echo ""; cat "$SNIPPET"; } >>"$target"
  else
    install -m 0644 "$SNIPPET" "$target"
  fi
  [[ "$(id -u)" -eq 0 ]] && chown "$REAL_USER:" "$target"
}

install_bins

# session hook — бонус (на части образов не вызывается)
for client in steam ogui-steam; do
  merge_session_file "$SESS_DIR/$client"
done

ENVF="${USER_HOME}/.config/environment.d/20-8bitdo-hdr.conf"
mkdir -p "$(dirname "$ENVF")"
cat >"$ENVF" <<'EOF'
# 1 = демон/nudge включены, 0 = выкл
HDR_NUDGE=1
# секунд ждать после появления gamescope перед toggle
HDR_NUDGE_DELAY=18
HDR_NUDGE_PASSES=2
HDR_NUDGE_SECOND_DELAY=6
# пауза между HDR off и on (сек) — нужна для modeset
HDR_TOGGLE_GAP=2.0
# Force Composite этот баг не чинит
HDR_FORCE_COMPOSITE=0
HDR_TOGGLE_NUDGE=1
EOF
[[ "$(id -u)" -eq 0 ]] && chown "$REAL_USER:" "$ENVF"

# user systemd unit + linger (критично: иначе демон умрёт при logout Desktop)
mkdir -p "$UNIT_DIR"
install -m 0644 "$ROOT/systemd/8bitdo-hdr-nudge.service" "$UNIT_DIR/8bitdo-hdr-nudge.service"
[[ "$(id -u)" -eq 0 ]] && chown -R "$REAL_USER:" "$UNIT_DIR"

if [[ "$(id -u)" -eq 0 ]]; then
  loginctl enable-linger "$REAL_USER" 2>/dev/null || true
fi

run_user systemctl --user daemon-reload || true
run_user systemctl --user enable --now 8bitdo-hdr-nudge.service || {
  echo "WARN: не удалось enable --now user-службу."
  echo "  В Desktop выполните:"
  echo "    systemctl --user enable --now 8bitdo-hdr-nudge.service"
  echo "    loginctl enable-linger $REAL_USER   # от root/sudo"
}

echo ""
echo "Installed HDR nudge daemon for: $REAL_USER"
echo ""
echo "Проверка:"
echo "  systemctl --user status 8bitdo-hdr-nudge.service"
echo "  tail -f ~/.cache/8bitdo-hdr-nudge.log"
echo ""
echo "Ожидание: после входа в Game Mode через ~20–30 с картинка «щёлкнет» (HDR off→on)."
echo "Если в логе пусто после перехода — служба не жива (linger / user bus)."
echo ""
echo "Выкл: HDR_NUDGE=0 в $ENVF  или  ./scripts/uninstall-hdr-workaround.sh"
