#!/bin/bash
# Печать версии Bazzite / наличия 44-зависимостей.
set -euo pipefail

echo "=== image-info ==="
if [[ -f /usr/share/ublue-os/image-info.json ]]; then
  cat /usr/share/ublue-os/image-info.json
else
  echo "(нет /usr/share/ublue-os/image-info.json)"
fi
echo ""

echo "=== ostree (кратко) ==="
rpm-ostree status 2>/dev/null | head -25 || true
echo ""

echo "=== Game Mode tools ==="
for c in steamosctl return-to-gamemode steamos-session-select 8bitdo-switch-gamemode; do
  if command -v "$c" >/dev/null 2>&1; then
    echo "  OK  $c -> $(command -v "$c")"
  else
    echo "  --  $c missing"
  fi
done
echo ""

echo "=== InputPlumber ==="
if systemctl list-unit-files inputplumber.service >/dev/null 2>&1; then
  echo "  unit: $(systemctl is-enabled inputplumber.service 2>/dev/null || echo '?') / $(systemctl is-active inputplumber.service 2>/dev/null || echo '?')"
  ls /etc/inputplumber/devices.d/19-custom-2dc8_*.yaml 2>/dev/null || echo "  (нет наших ignore yaml)"
else
  echo "  (нет inputplumber.service — не deck 44 или отключён)"
fi
echo ""

echo "=== рекомендация ==="
FEDORA=""
if [[ -f /usr/share/ublue-os/image-info.json ]]; then
  FEDORA=$(jq -r '."fedora-version" // .fedora_version // empty' /usr/share/ublue-os/image-info.json 2>/dev/null || true)
fi
if [[ "$FEDORA" == "44" ]] || command -v steamosctl >/dev/null 2>&1; then
  echo "Похоже на Bazzite 44 / steamosctl-стек → sudo ./compat/bazzite44/scripts/install-bazzite44.sh"
else
  echo "Похоже на pre-44 → основные скрипты без compat/bazzite44"
fi
