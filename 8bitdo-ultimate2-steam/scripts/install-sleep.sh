#!/bin/bash
# Установка рабочего фикса сна/дока на Bazzite (ostree: /usr read-only).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN=/usr/local/bin
LIB=/usr/local/lib
ETC=/etc

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Запустите через sudo: sudo $0" >&2
  exit 1
fi

install -d "$BIN" "$LIB" "$ETC" \
  "$ETC/systemd/system/systemd-suspend.service.d" \
  "$ETC/systemd/system/systemd-hybrid-sleep.service.d" \
  "$ETC/systemd/system/systemd-suspend-then-hibernate.service.d"

install -m 0755 "$ROOT/scripts/8bitdo-pre-suspend.sh" "$BIN/8bitdo-pre-suspend.sh"
install -m 0755 "$ROOT/scripts/8bitdo-post-resume.sh" "$BIN/8bitdo-post-resume.sh"
install -m 0644 "$ROOT/scripts/8bitdo-common.sh" "$LIB/8bitdo-common.sh"

if [[ ! -f "$ETC/8bitdo-sleep.conf" ]]; then
  install -m 0644 "$ROOT/config/8bitdo-sleep.conf" "$ETC/8bitdo-sleep.conf"
fi

for svc in systemd-suspend systemd-hybrid-sleep systemd-suspend-then-hibernate; do
  install -m 0644 "$ROOT/systemd/8bitdo-suspend.conf" \
    "$ETC/systemd/system/${svc}.service.d/8bitdo.conf"
done

systemctl daemon-reload
echo "8bitdo sleep hooks installed. Config: $ETC/8bitdo-sleep.conf"
echo "MODE=wait (ждать док до 20с) или MODE=delay (всегда 20с)."
