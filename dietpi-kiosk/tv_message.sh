#!/bin/bash
# Show a text message on Xiaomi TV via ADB (no file permission dialog).
# Target: /root/tv_message.sh
#
# Usage:
#   /root/tv_message.sh Hello world
#   TITLE="Внимание" /root/tv_message.sh Текст
#   TITLE="Временно" DURATION_SEC=20 /root/tv_message.sh ...
#   echo "текст" | /root/tv_message.sh

set -euo pipefail

TV_ADB="${TV_ADB:-192.168.0.2:5555}"
TITLE="${TITLE:-Сообщение}"
DURATION_SEC="${DURATION_SEC:-0}"

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

# One-time: grant storage to HTML viewer (avoids "Разрешить" dialog if file:// used)
adb -s "$TV_ADB" shell pm grant com.android.htmlviewer android.permission.READ_EXTERNAL_STORAGE >/dev/null 2>&1 || true
adb -s "$TV_ADB" shell appops set com.android.htmlviewer READ_EXTERNAL_STORAGE allow >/dev/null 2>&1 || true

# Prefer data: URI — no sdcard file, no permission prompt
DATA_URI="$(
  TITLE="$TITLE" MSG="$MSG" python3 - <<'PY'
import os, urllib.parse, html as htmlmod
title = htmlmod.escape(os.environ.get("TITLE", "Сообщение"))
msg = htmlmod.escape(os.environ.get("MSG", "")).replace("\n", "<br>")
page = f"""<!DOCTYPE html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
html,body{{margin:0;height:100%;background:#0b0f14;color:#e8eef5;
font-family:sans-serif;display:flex;align-items:center;justify-content:center}}
.box{{max-width:90vw;text-align:center;padding:4vh 4vw}}
h1{{font-size:6vw;font-weight:700;margin:0 0 3vh;color:#7dd3fc}}
p{{font-size:4.5vw;line-height:1.35;margin:0}}
</style></head>
<body><div class="box"><h1>{title}</h1><p>{msg}</p></div></body></html>"""
print("data:text/html;charset=utf-8," + urllib.parse.quote(page))
PY
)"

opened=0
# Explicit HTMLViewer + data: URI (no file access)
if adb -s "$TV_ADB" shell am start \
  -n com.android.htmlviewer/.HTMLViewerActivity \
  -a android.intent.action.VIEW \
  -d "$DATA_URI" \
  -t text/html >/dev/null 2>&1; then
  echo "Opened HTMLViewer via data: URI"
  opened=1
elif adb -s "$TV_ADB" shell am start \
  -a android.intent.action.VIEW \
  -d "$DATA_URI" \
  -t text/html >/dev/null 2>&1; then
  echo "Opened VIEW data: URI"
  opened=1
fi

# Fallback: file on sdcard (permission already granted above)
if [ "$opened" -eq 0 ]; then
  HTML_PATH="/sdcard/tv_message.html"
  TITLE="$TITLE" MSG="$MSG" python3 - <<'PY' | adb -s "$TV_ADB" shell "cat > /sdcard/tv_message.html"
import os, html as htmlmod
title = htmlmod.escape(os.environ.get("TITLE", "Сообщение"))
msg = htmlmod.escape(os.environ.get("MSG", "")).replace("\n", "<br>")
print(f"""<!DOCTYPE html><html><head><meta charset="utf-8">
<style>
html,body{{margin:0;height:100%;background:#0b0f14;color:#e8eef5;
font-family:sans-serif;display:flex;align-items:center;justify-content:center}}
.box{{max-width:90vw;text-align:center;padding:4vh 4vw}}
h1{{font-size:6vw;margin:0 0 3vh;color:#7dd3fc}}
p{{font-size:4.5vw;line-height:1.35;margin:0}}
</style></head>
<body><div class="box"><h1>{title}</h1><p>{msg}</p></div></body></html>""")
PY
  if adb -s "$TV_ADB" shell am start -n com.android.htmlviewer/.HTMLViewerActivity \
    -a android.intent.action.VIEW -d "file://${HTML_PATH}" -t text/html >/dev/null 2>&1; then
    echo "Opened HTMLViewer via file (fallback)"
    opened=1
    # Auto-tap "Разрешить" if permission dialog still appears
    sleep 1
    adb -s "$TV_ADB" shell input tap 1536 707 >/dev/null 2>&1 || true
  fi
fi

if [ "$opened" -eq 0 ]; then
  echo "ERROR: could not open message on TV" >&2
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
fi

exit 0
