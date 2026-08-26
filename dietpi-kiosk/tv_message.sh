#!/bin/bash
# Show a text message on Xiaomi TV via ADB.
# Target: /root/tv_message.sh
#
# Usage:
#   /root/tv_message.sh Hello world
#   /root/tv_message.sh "Проверка киоска"
#   echo "текст" | /root/tv_message.sh
#   TITLE="Внимание" /root/tv_message.sh Перезагрузка через 1 мин
#
# Env:
#   TV_ADB=192.168.0.2:5555
#   TITLE=Сообщение
#   DURATION_SEC=0   — if >0, after N seconds return to HDMI 3 / home

set -euo pipefail

TV_ADB="${TV_ADB:-192.168.0.2:5555}"
TITLE="${TITLE:-Сообщение}"
DURATION_SEC="${DURATION_SEC:-0}"
HTML_PATH="/sdcard/tv_message.html"

adb_online() {
  adb connect "$TV_ADB" >/dev/null 2>&1 || true
  adb devices 2>/dev/null | grep -qE "^${TV_ADB}[[:space:]]+device$"
}

if [ "$#" -gt 0 ]; then
  MSG="$*"
else
  MSG="$(cat)"
fi

MSG="$(printf '%s' "$MSG" | tr -d '\r')"
if [ -z "$MSG" ]; then
  echo "Usage: $0 <text>   or   echo text | $0" >&2
  exit 1
fi

if ! adb_online; then
  echo "ERROR: ADB offline ($TV_ADB) — TV must be on / in standby with network" >&2
  exit 1
fi

# Escape for HTML
html_escape() {
  printf '%s' "$1" | sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g' \
    -e 's/"/\&quot;/g'
}

TITLE_E="$(html_escape "$TITLE")"
# Preserve newlines as <br>
MSG_E="$(html_escape "$MSG" | sed ':a;N;$!ba;s/\n/<br>/g')"

HTML=$(cat <<EOF
<!DOCTYPE html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
  html,body{margin:0;height:100%;background:#0b0f14;color:#e8eef5;
    font-family:sans-serif;display:flex;align-items:center;justify-content:center;}
  .box{max-width:90vw;text-align:center;padding:4vh 4vw;}
  h1{font-size:6vw;font-weight:700;margin:0 0 3vh;color:#7dd3fc;}
  p{font-size:4.5vw;line-height:1.35;margin:0;white-space:pre-wrap;}
</style></head>
<body><div class="box"><h1>${TITLE_E}</h1><p>${MSG_E}</p></div></body></html>
EOF
)

# Push HTML without shell-quoting hell
printf '%s' "$HTML" | adb -s "$TV_ADB" shell "cat > $HTML_PATH"

# 1) Big notification (shade / brief banner on many ATVs)
if adb -s "$TV_ADB" shell cmd notification post \
  -S bigtext \
  -t "$TITLE" \
  "tv_message" \
  "$MSG" >/dev/null 2>&1; then
  echo "Notification posted"
else
  echo "WARN: cmd notification post failed (ignored)" >&2
fi

# 2) Fullscreen HTML — try common viewers / VIEW intent
opened=0
try_open() {
  # shellcheck disable=SC2086
  if adb -s "$TV_ADB" shell "$@" >/dev/null 2>&1; then
    echo "Opened on TV: $*"
    return 0
  fi
  return 1
}

if try_open am start -a android.intent.action.VIEW -d "file://${HTML_PATH}" -t text/html \
  || try_open am start -a android.intent.action.VIEW -d "file://${HTML_PATH}" \
  || try_open am start -n com.android.chrome/com.google.android.apps.chrome.Main -d "file://${HTML_PATH}" \
  || try_open am start -n com.android.browser/.BrowserActivity -d "file://${HTML_PATH}"; then
  opened=1
fi

if [ "$opened" -eq 0 ]; then
  # data: URI fallback (URL-encoded)
  DATA_URI="$(
    TITLE="$TITLE" MSG="$MSG" python3 - <<'PY'
import os, urllib.parse
title = os.environ.get("TITLE", "Сообщение")
msg = os.environ.get("MSG", "")
html = (
    "<!DOCTYPE html><html><head><meta charset=utf-8>"
    "<style>body{margin:0;background:#0b0f14;color:#e8eef5;font-family:sans-serif;"
    "display:flex;align-items:center;justify-content:center;height:100vh}"
    ".box{max-width:90vw;text-align:center}h1{font-size:6vw;color:#7dd3fc}"
    "p{font-size:4.5vw;line-height:1.35;white-space:pre-wrap}</style></head>"
    f"<body><div class=box><h1>{title}</h1><p>{msg}</p></div></body></html>"
)
print("data:text/html;charset=utf-8," + urllib.parse.quote(html))
PY
  )"
  if adb -s "$TV_ADB" shell am start -a android.intent.action.VIEW -d "$DATA_URI" >/dev/null 2>&1; then
    echo "Opened data: URI on TV"
    opened=1
  fi
fi

if [ "$opened" -eq 0 ]; then
  echo "WARN: could not open fullscreen view — notification may still be visible" >&2
fi

echo "Message sent to TV ($TV_ADB): $TITLE — $MSG"

if [ "$DURATION_SEC" -gt 0 ] 2>/dev/null; then
  echo "Returning in ${DURATION_SEC}s..."
  sleep "$DURATION_SEC"
  # back toward kiosk / HDMI 3 if possible
  adb -s "$TV_ADB" shell input keyevent 3 >/dev/null 2>&1 || true
  adb -s "$TV_ADB" shell am start -a com.mitv.tvhome.atv.app.tv.INPUTSOURCE_POPUP >/dev/null 2>&1 || true
  sleep 1
  adb -s "$TV_ADB" shell input tap 640 410 >/dev/null 2>&1 || true
fi

exit 0
