#!/bin/bash
# HTPC: автовход в Plasma (Desktop), Game Mode только по ярлыку/хоткею.
# На Bazzite 44 steamosctl set-default-login-mode desktop иногда не цепляется —
# SDDM читает /etc/sddm.conf.d/zz-holo-autologin.conf (Session=...).
#
#   sudo ./scripts/fix-desktop-autologin.sh
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Запустите: sudo $0" >&2
  exit 1
fi

IMAGE_INFO="/usr/share/ublue-os/image-info.json"
BASE="kinoite"
if [[ -f "$IMAGE_INFO" ]]; then
  BASE="$(jq -r '."base-image-name" // empty' "$IMAGE_INFO" 2>/dev/null || true)"
fi
case "$BASE" in
  *silverblue*) SESSION="gnome.desktop" ;;
  *) SESSION="plasma.desktop" ;;
esac

echo "=== Сейчас в /etc/sddm.conf.d/ ==="
ls -la /etc/sddm.conf.d/ 2>/dev/null || true
for f in /etc/sddm.conf.d/*.conf; do
  [[ -f "$f" ]] || continue
  echo "--- $f ---"
  cat "$f"
  echo
done

# steamosctl (если есть) — официальный путь
if command -v steamosctl >/dev/null 2>&1; then
  steamosctl set-default-login-mode desktop || true
  steamosctl set-default-desktop-session "$SESSION" 2>/dev/null || true
  echo "steamosctl get-default-login-mode: $(steamosctl get-default-login-mode 2>/dev/null || echo '?')"
fi

# Sentinel для bazzite-autologin: если zz-holo пересоздадут — возьмут Plasma
mkdir -p /etc/bazzite
touch /etc/bazzite/desktop_autologin
echo "Created /etc/bazzite/desktop_autologin"

# Жёстко: Session в файле, который SDDM читает после vendor holo.conf
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/zz-holo-autologin.conf <<EOF
[Autologin]
Session=${SESSION}
EOF
echo "Wrote /etc/sddm.conf.d/zz-holo-autologin.conf → Session=${SESSION}"

# Временные one-shot файлы, которые могут перебить на gamescope
for junk in /etc/sddm.conf.d/zzt-steamos-temp-login.conf \
            /etc/sddm.conf.d/zz-steamos-autologin.conf; do
  if [[ -f "$junk" ]]; then
    mv -v "$junk" "${junk}.bak.$(date +%s)" || true
  fi
done

echo ""
echo "Готово. Перезагрузка:"
echo "  systemctl reboot"
echo "Если снова Game Mode — пришлите: ls /etc/sddm.conf.d/ && grep -r Session /etc/sddm.conf.d/"
