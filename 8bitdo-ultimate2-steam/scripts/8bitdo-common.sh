# Общие функции для pre-suspend / post-resume.
# VID 8BitDo = 2dc8
# 6013 = idle (геймпад выключен / на доке)
# 6012 = D-Input, 310b = XInput

EIGHTBITDO_VENDOR="2dc8"
PID_IDLE="6013"
PID_DINPUT="6012"
PID_XINPUT="310b"

FLAG_IDLE="/run/8bitdo-slept-idle"
FLAG_ACTIVE="/run/8bitdo-slept-active"
RESUSPEND_STAMP="/run/8bitdo-resuspend-stamp"

log() {
  logger -t 8bitdo-sleep -- "$*"
  echo "8bitdo-sleep: $*" >&2
}

8bitdo_products() {
  local d vendor product
  for d in /sys/bus/usb/devices/*; do
    [[ -f "$d/idVendor" && -f "$d/idProduct" ]] || continue
    vendor="$(tr -d '[:space:]' <"$d/idVendor" | tr 'A-F' 'a-f')"
    [[ "$vendor" == "$EIGHTBITDO_VENDOR" ]] || continue
    product="$(tr -d '[:space:]' <"$d/idProduct" | tr 'A-F' 'a-f')"
    printf '%s\n' "$product"
  done
}

8bitdo_has_pid() {
  local want="$1"
  8bitdo_products | grep -qx "$want"
}

8bitdo_is_idle() {
  local products
  products="$(8bitdo_products | sort -u)"
  if [[ -z "$products" ]]; then
    return 0
  fi
  if echo "$products" | grep -qx "$PID_DINPUT"; then
    return 1
  fi
  if echo "$products" | grep -qx "$PID_XINPUT"; then
    return 1
  fi
  if echo "$products" | grep -qx "$PID_IDLE"; then
    return 0
  fi
  # Другой PID 8BitDo (например Switch) — считаем активным.
  return 1
}

8bitdo_is_controller_on() {
  8bitdo_has_pid "$PID_DINPUT" || 8bitdo_has_pid "$PID_XINPUT"
}

clear_sleep_flags() {
  rm -f "$FLAG_IDLE" "$FLAG_ACTIVE"
}

mark_slept_idle() {
  clear_sleep_flags
  echo 1 >"$FLAG_IDLE"
}

mark_slept_active() {
  clear_sleep_flags
  echo 1 >"$FLAG_ACTIVE"
}

load_sleep_config() {
  MODE="${MODE:-wait}"
  TIMEOUT="${TIMEOUT:-20}"
  SLEEP_DELAY="${SLEEP_DELAY:-20}"
  RESUSPEND_DELAY="${RESUSPEND_DELAY:-2}"
  local f
  for f in /etc/8bitdo-sleep.conf /usr/local/etc/8bitdo-sleep.conf; do
    if [[ -f "$f" ]]; then
      # shellcheck disable=SC1090
      source "$f"
    fi
  done
}
