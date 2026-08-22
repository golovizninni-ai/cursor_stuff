#!/bin/bash
# Обход «выбеленный / rainbow HDR» при входе в Game Mode (Desktop → Game Mode).
#
# Главный ручной фикс (Bazzite docs «Rainbow Display»):
#   1) Steam → Settings → System → Enable developer mode
#   2) Developer → Force Composite
#   3) При выбелении: QAM (…) → Display → HDR off → on
#
# Этот скрипт ставит авто-nudge после старта gamescope (xprop-атомы).
#
#   ./scripts/install-hdr-workaround.sh          # от пользователя
#   sudo ./scripts/install-hdr-workaround.sh     # + /usr/local/bin
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MARKER_BEGIN="# BEGIN 8bitdo-hdr-nudge"
MARKER_END="# END 8bitdo-hdr-nudge"

if [[ "$(id -u)" -eq 0 && -n "${SUDO_USER:-}" ]]; then
  REAL_USER="$SUDO_USER"
  USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
  REAL_USER="${SUDO_USER:-$USER}"
  USER_HOME="$HOME"
fi

SESS_DIR="${USER_HOME}/.config/gamescope-session-plus/sessions.d"
BIN_USER="${USER_HOME}/.local/bin"
SNIPPET="$ROOT/config/gamescope-session-hdr-nudge.sh"

install_nudge_bin() {
  mkdir -p "$BIN_USER"
  install -m 0755 "$ROOT/scripts/8bitdo-hdr-nudge.sh" "$BIN_USER/8bitdo-hdr-nudge.sh"
  if [[ "$(id -u)" -eq 0 ]]; then
    install -m 0755 "$ROOT/scripts/8bitdo-hdr-nudge.sh" /usr/local/bin/8bitdo-hdr-nudge.sh
    [[ -n "${SUDO_USER:-}" ]] && chown "$SUDO_USER:" "$BIN_USER/8bitdo-hdr-nudge.sh"
  fi
}

# Вмержить snippet в sessions.d/<client>, не затирая чужой конфиг целиком
merge_session_file() {
  local target="$1"
  mkdir -p "$(dirname "$target")"
  if [[ -f "$target" ]] && grep -qF "$MARKER_BEGIN" "$target"; then
    # заменить старый блок
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
    {
      echo ""
      cat "$SNIPPET"
    } >>"$target"
  else
    install -m 0644 "$SNIPPET" "$target"
  fi
  if [[ "$(id -u)" -eq 0 && -n "${SUDO_USER:-}" ]]; then
    chown "$SUDO_USER:" "$target"
  fi
}

install_nudge_bin

for client in steam ogui-steam; do
  merge_session_file "$SESS_DIR/$client"
done

ENVF="${USER_HOME}/.config/environment.d/20-8bitdo-hdr.conf"
mkdir -p "$(dirname "$ENVF")"
if [[ ! -f "$ENVF" ]]; then
  cat >"$ENVF" <<'EOF'
# Авто-nudge HDR после старта Game Mode (1=вкл, 0=выкл)
HDR_NUDGE=1
# Секунд ждать Steam UI перед toggle HDR
HDR_NUDGE_DELAY=12
# Выставить GAMESCOPE_COMPOSITE_FORCE=1 (как Developer → Force Composite)
HDR_FORCE_COMPOSITE=1
# Сделать off→on GAMESCOPE_DISPLAY_HDR_ENABLED (как QAM HDR toggle)
HDR_TOGGLE_NUDGE=1
EOF
  [[ "$(id -u)" -eq 0 && -n "${SUDO_USER:-}" ]] && chown "$SUDO_USER:" "$ENVF"
fi

echo ""
echo "Installed HDR workaround hooks for user: $REAL_USER"
echo ""
echo "=== Сначала вручную (главный фикс) ==="
echo "1. Game Mode → Settings → System → Enable developer mode"
echo "2. Developer → включить Force Composite"
echo "3. Если картинка выбелена: QAM (…) → Display → HDR off → on"
echo ""
echo "Авто-nudge (эксперимент, тот же путь через X-атомы):"
echo "  sessions: $SESS_DIR/{steam,ogui-steam}"
echo "  binary:   $BIN_USER/8bitdo-hdr-nudge.sh"
echo "  log:      ~/.cache/8bitdo-hdr-nudge.log"
echo "  config:   $ENVF"
echo ""
echo "Перезайдите в Game Mode, чтобы hook подхватился."
echo "Отключить: HDR_NUDGE=0 в $ENVF  или  ./scripts/uninstall-hdr-workaround.sh"
