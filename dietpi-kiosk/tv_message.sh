#!/bin/bash
# Show a text message on Xiaomi TV via ADB + local HTTP (WebView).
# Target: /root/tv_message.sh
#
# Usage:
#   /root/tv_message.sh Hello world
#   TITLE="Внимание" /root/tv_message.sh Текст
#   TITLE="Временно" DURATION_SEC=20 /root/tv_message.sh ...
#   echo "текст" | /root/tv_message.sh
#
# Serves HTML from NUC (python http.server) and opens it on TV WebView.
# Avoids file:// / data: URI errors on Xiaomi HTMLViewer.

set -euo pipefail

TV_ADB="${TV_ADB:-192.168.0.2:5555}"
TITLE="${TITLE:-Сообщение}"
DURATION_SEC="${DURATION_SEC:-0}"
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

# Restart tiny HTTP server
if [ -f "$PID_FILE" ]; then
  kill "$(cat "$PID_FILE")" 2>/dev/null || true
  rm -f "$PID_FILE"
fi
pkill -f "http.server ${HTTP_PORT}" 2>/dev/null || true
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

echo "Message on TV ($TV_ADB): $TITLE — $MSG"

if [ "$DURATION_SEC" -gt 0 ] 2>/dev/null; then
  echo "Returning in ${DURATION_SEC}s..."
  sleep "$DURATION_SEC"
  adb -s "$TV_ADB" shell input keyevent 3 >/dev/null 2>&1 || true
  adb -s "$TV_ADB" shell am start -a com.mitv.tvhome.atv.app.tv.INPUTSOURCE_POPUP >/dev/null 2>&1 || true
  sleep 1
  adb -s "$TV_ADB" shell input tap 640 410 >/dev/null 2>&1 || true
  if [ -f "$PID_FILE" ]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
  fi
fi

exit 0
