#!/bin/bash
# Разово снять следы отменённого HDR-workaround (служба, бинарники, sessions.d).
# Не ставит ничего нового.
set -euo pipefail

if [[ "$(id -u)" -eq 0 && -n "${SUDO_USER:-}" ]]; then
  U="$SUDO_USER"
  H="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
  UID_N="$(id -u "$SUDO_USER")"
else
  U="$USER"
  H="$HOME"
  UID_N="$(id -u)"
fi
R="/run/user/${UID_N}"

run_user() {
  if [[ "$(id -u)" -eq 0 ]]; then
    sudo -u "$U" -H env HOME="$H" XDG_RUNTIME_DIR="$R" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=${R}/bus" "$@"
  else
    "$@"
  fi
}

run_user systemctl --user disable --now 8bitdo-hdr-nudge.service 2>/dev/null || true
rm -f "$H/.config/systemd/user/8bitdo-hdr-nudge.service"
run_user systemctl --user daemon-reload 2>/dev/null || true

# sessions.d: убрать наш блок / файлы, которые могли перебить Decky / steam-tweaks
for f in "$H/.config/gamescope-session-plus/sessions.d/steam" \
         "$H/.config/gamescope-session-plus/sessions.d/ogui-steam"; do
  [[ -f "$f" ]] || continue
  if grep -q '8bitdo-hdr-nudge\|BEGIN 8bitdo-hdr' "$f" 2>/dev/null; then
    if grep -qE 'GAMESCOPECMD|STEAMCMD|CLIENTCMD|steam-tweaks' "$f"; then
      tmp="$(mktemp)"
      awk '
        /^# BEGIN 8bitdo-hdr-nudge$/ {skip=1; next}
        /^# END 8bitdo-hdr-nudge$/ {skip=0; next}
        !skip {print}
      ' "$f" >"$tmp"
      mv "$tmp" "$f"
    else
      # файл только наш — удалить целиком (вернуть системный sessions.d)
      rm -f "$f"
    fi
    echo "cleaned $f"
  fi
done

rm -f /usr/local/bin/8bitdo-hdr-nudge.sh \
      /usr/local/bin/8bitdo-hdr-nudge-daemon.sh \
      /usr/local/bin/8bitdo-hdr-toggle.py \
      "$H/.local/bin/8bitdo-hdr-nudge.sh" \
      "$H/.local/bin/8bitdo-hdr-nudge-daemon.sh" \
      "$H/.local/bin/8bitdo-hdr-toggle.py" \
      "$H/.config/environment.d/20-8bitdo-hdr.conf" \
      "$H/.cache/8bitdo-hdr-nudge.log"

echo "HDR leftovers removed for $U."
echo "Перезайди в Game Mode / Desktop. Decky: переустанови плагин или ujust/Decky installer при необходимости."
