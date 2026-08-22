# BEGIN 8bitdo-hdr-nudge
# User override для gamescope-session-plus (Bazzite / ChimeraOS).
# Клиент: steam (сессии 43) или ogui-steam (Bazzite Deck 44).
# post_gamescope_start — сразу после старта compositor, DISPLAY уже gamescope Xwayland.

post_gamescope_start() {
  if [[ "${HDR_NUDGE:-1}" == "0" ]]; then
    return 0
  fi
  local nudge=""
  if [[ -x /usr/local/bin/8bitdo-hdr-nudge.sh ]]; then
    nudge=/usr/local/bin/8bitdo-hdr-nudge.sh
  elif [[ -x "${HOME}/.local/bin/8bitdo-hdr-nudge.sh" ]]; then
    nudge="${HOME}/.local/bin/8bitdo-hdr-nudge.sh"
  fi
  if [[ -n "$nudge" ]]; then
    # фон: не блокируем старт Steam
    "$nudge" &
  fi
}
# END 8bitdo-hdr-nudge
