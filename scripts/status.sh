#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

resolve_variant "${1:-}"
MODE="$(read_install_mode "$VARIANT")"

echo "вариант: $VARIANT  режим: $MODE"
echo "активный стек: $(read_active_variant 2>/dev/null || echo «не задан»)"

if [[ "$MODE" == "docker" ]]; then
  dc ps || true
  echo
  world="$(docker_world_container "$VARIANT")"
  if docker inspect "$world" >/dev/null 2>&1; then
    echo "world: $(docker inspect -f 'status={{.State.Status}} running={{.State.Running}} restarts={{.RestartCount}}' "$world")"
    if docker inspect -f '{{.State.Status}}' "$world" | grep -q restarting; then
      echo "ВНИМАНИЕ: worldserver в Restarting — смотрите логи:"
      echo "  docker logs --tail 200 $world"
    fi
  fi
  echo
  echo "логи: docker logs -f $world"
  echo "консоль: docker attach $world   (отцепление Ctrl+P Ctrl+Q)"
else
  systemd_for_variant "$VARIANT"
  echo "systemd scope: $UNIT_SCOPE"
  sc --no-pager --full status "$(auth_unit "$VARIANT")" "$(world_unit "$VARIANT")" || true
  echo
  echo "автозапуск:"
  sc is-enabled "$(auth_unit "$VARIANT")" 2>/dev/null || true
  sc is-enabled "$(world_unit "$VARIANT")" 2>/dev/null || true
fi

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
