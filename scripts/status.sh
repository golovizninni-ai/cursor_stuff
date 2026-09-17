#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

resolve_variant "${1:-}"
systemd_for_variant "$VARIANT"

echo "вариант: $VARIANT  (native)"
echo "активный стек: $(read_active_variant 2>/dev/null || echo «не задан»)"
echo "установлены: $(list_installed_variants | tr '\n' ' ' || echo «ничего»)"
echo "systemd scope: $UNIT_SCOPE"
sc --no-pager --full status "$(auth_unit "$VARIANT")" "$(world_unit "$VARIANT")" || true
echo
echo "автозапуск:"
sc is-enabled "$(auth_unit "$VARIANT")" 2>/dev/null || true
sc is-enabled "$(world_unit "$VARIANT")" 2>/dev/null || true

if [[ -f "$AC_ROOT/$VARIANT/ollama-chat" ]]; then
  echo
  echo "ollama-chat: модель $(tr -d '[:space:]' <"$AC_ROOT/$VARIANT/ollama-chat")"
  if command -v ollama >/dev/null 2>&1; then
    systemctl is-active --quiet ollama && echo "ollama.service: active" || echo "ollama.service: не запущен"
    curl -sf --max-time 2 http://127.0.0.1:11434/api/tags >/dev/null \
      && echo "API 11434: ок" \
      || echo "API 11434: нет ответа"
  else
    echo "бинарника ollama нет — scripts/enable-ollama-chat.sh playerbots"
  fi
fi
