#!/bin/bash
# Show a text message on Xiaomi TV via ADB + local HTTP (WebView).
# Target: /root/tv_message.sh
#
# Interactive:
#   /root/tv_message.sh
#   → плашка сверху (Enter = Сообщение)
#   → текст
#   → секунды (0 = без таймера, Ctrl+C чтобы снять)
#
# Non-interactive:
#   /root/tv_message.sh "текст" 30
#   TITLE="Алерт" /root/tv_message.sh "текст" 0
#   /root/tv_message.sh "Алерт" "текст" 30
#
# After timer (sec > 0): switch TV back to HDMI 3.

set -euo pipefail

TV_ADB="${TV_ADB:-192.168.0.2:5555}"
TITLE="${TITLE:-Сообщение}"
HTTP_PORT="${HTTP_PORT:-8765}"
WWW_DIR="${WWW_DIR:-/tmp/tvmsg}"
PID_FILE="/tmp/tvmsg-http.pid"

adb_online() {
  adb connect "$TV_ADB" >/dev/null 2>&1 || true
  adb devices 2>/dev/null | grep -qE "^${TV_ADB}[[:space:]]+device$"
}

nuc_ip_toward_tv() {
  local host="${TV_ADB%%:*}"
  ip -4 route get "$host" 2>/dev/null \
    | awk '{for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit }}'
}

switch_hdmi3() {
  echo "Switching TV back to HDMI 3..."
  adb -s "$TV_ADB" shell input keyevent 3 >/dev/null 2>&1 || true
  adb -s "$TV_ADB" shell am force-stop org.chromium.webview_shell >/dev/null 2>&1 || true
  adb -s "$TV_ADB" shell am start -a com.mitv.tvhome.atv.app.tv.INPUTSOURCE_POPUP >/dev/null 2>&1 || true
  sleep 1
  adb -s "$TV_ADB" shell input tap 640 410 >/dev/null 2>&1 || true
}

stop_http() {
  if [ -f "$PID_FILE" ]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
  fi
  pkill -f "http.server ${HTTP_PORT}" 2>/dev/null || true
}

cleanup() {
  stop_http
}
trap cleanup EXIT

# --- interactive prompts when no args ---
MSG=""
DURATION_SEC=""

if [ "$#" -eq 0 ]; then
  if [ -t 0 ]; then
    echo -n "Плашка сверху (Enter = Сообщение): "
    IFS= read -r TITLE_IN
    TITLE_IN="$(printf '%s' "$TITLE_IN" | tr -d '\r')"
    [ -n "$TITLE_IN" ] && TITLE="$TITLE_IN"

    echo -n "Текст для ТВ: "
    IFS= read -r MSG

    echo -n "Сколько секунд показывать (0 = без таймера): "
    IFS= read -r DURATION_SEC
  else
    MSG="$(cat)"
    DURATION_SEC=0
  fi
elif [ "$#" -eq 1 ]; then
  MSG="$1"
elif [ "$#" -eq 2 ]; then
  MSG="$1"
  DURATION_SEC="$2"
else
  TITLE="$1"
  MSG="$2"
  DURATION_SEC="$3"
fi

MSG="$(printf '%s' "$MSG" | tr -d '\r')"
if [ -z "$MSG" ]; then
  echo "Пустой текст — выход." >&2
  exit 1
fi

if [ -z "${DURATION_SEC}" ]; then
  if [ -t 0 ]; then
    echo -n "Сколько секунд показывать (0 = без таймера): "
    IFS= read -r DURATION_SEC
  else
    DURATION_SEC=0
  fi
fi

DURATION_SEC="$(printf '%s' "$DURATION_SEC" | tr -d '[:space:]')"
if ! [[ "$DURATION_SEC" =~ ^[0-9]+$ ]]; then
  echo "ERROR: время должно быть целым числом секунд (получено: '$DURATION_SEC')" >&2
  exit 1
fi

if ! adb_online; then
  echo "ERROR: ADB offline ($TV_ADB)" >&2
  exit 1
fi

NUC_IP="$(nuc_ip_toward_tv)"
if [ -z "$NUC_IP" ]; then
  echo "ERROR: cannot detect NUC IP toward TV" >&2
  exit 1
fi

mkdir -p "$WWW_DIR"
TITLE="$TITLE" MSG="$MSG" python3 - <<'PY' > "$WWW_DIR/index.html"
import os, html as H
title = H.escape(os.environ.get("TITLE", "Сообщение"))
msg = H.escape(os.environ.get("MSG", "")).replace("\n", "<br>")
print(f"""<!DOCTYPE html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
html,body{{margin:0;height:100%;background:#0b0f14;color:#e8eef5;
font-family:sans-serif;display:flex;align-items:center;justify-content:center}}
.box{{max-width:90vw;text-align:center;padding:4vh 4vw}}
h1{{font-size:6vw;font-weight:700;margin:0 0 3vh;color:#7dd3fc}}
p{{font-size:4.5vw;line-height:1.35;margin:0}}
</style></head>
<body><div class="box"><h1>{title}</h1><p>{msg}</p></div></body></html>""")
PY

stop_http
(
  cd "$WWW_DIR"
  nohup python3 -m http.server "$HTTP_PORT" --bind 0.0.0.0 \
    > /tmp/tvmsg-http.log 2>&1 &
  echo $! > "$PID_FILE"
)
sleep 0.4

URL="http://${NUC_IP}:${HTTP_PORT}/index.html?t=$(date +%s)"
echo "Serving $URL"

adb -s "$TV_ADB" shell am force-stop org.chromium.webview_shell >/dev/null 2>&1 || true
adb -s "$TV_ADB" shell am force-stop com.android.htmlviewer >/dev/null 2>&1 || true

if ! adb -s "$TV_ADB" shell am start \
  -n org.chromium.webview_shell/.WebViewBrowserActivity \
  -a android.intent.action.VIEW \
  -d "$URL" >/dev/null 2>&1; then
  echo "ERROR: failed to start WebViewBrowserActivity" >&2
  exit 1
fi

echo "На ТВ: $TITLE — $MSG"

if [ "$DURATION_SEC" -eq 0 ]; then
  echo "Без таймера. Ctrl+C — закрыть HTTP и выйти (HDMI 3 не трогаем)."
  # Keep serving until interrupted
  if [ -f "$PID_FILE" ]; then
    wait "$(cat "$PID_FILE")" 2>/dev/null || tail -f /dev/null
  else
    tail -f /dev/null
  fi
else
  echo "Показ ${DURATION_SEC} с, затем HDMI 3..."
  sleep "$DURATION_SEC"
  switch_hdmi3
  echo "Готово."
fi

exit 0
