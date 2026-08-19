#!/usr/bin/env bash
# Скачать модели в локальную Ollama (контейнер должен быть запущен).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

ollama() {
  docker compose exec -T ollama ollama "$@"
}

usage() {
  cat <<EOF
Использование: $0 <набор>

  core     вопросы 7B + код 7B + маленькие 3B (рекомендуется для 1660 Ti)
  chat     только ${MODEL_CHAT:-qwen2.5:7b}
  coder    только ${MODEL_CODER:-qwen2.5-coder:7b}
  small    3B — если 7B не влезает рядом с Immich
  tiny     3B chat+coder без 7B

Примеры:
  $0 core
  $0 small
EOF
}

set_name="${1:-}"
[[ -n "$set_name" ]] || { usage; exit 1; }

if ! docker compose ps --status running --services 2>/dev/null | grep -qx ollama; then
  echo "Сначала: docker compose up -d ollama"
  exit 1
fi

pull() {
  echo "==> ollama pull $1"
  ollama pull "$1"
}

case "$set_name" in
  core)
    pull "${MODEL_CHAT_SMALL:-qwen2.5:3b}"
    pull "${MODEL_CODER_SMALL:-qwen2.5-coder:3b}"
    pull "${MODEL_CHAT:-qwen2.5:7b}"
    pull "${MODEL_CODER:-qwen2.5-coder:7b}"
    "$ROOT/scripts/create-modelfiles.sh" || true
    ;;
  chat)
    pull "${MODEL_CHAT:-qwen2.5:7b}"
    ;;
  coder)
    pull "${MODEL_CODER:-qwen2.5-coder:7b}"
    ;;
  small | tiny)
    pull "${MODEL_CHAT_SMALL:-qwen2.5:3b}"
    pull "${MODEL_CODER_SMALL:-qwen2.5-coder:3b}"
    ;;
  *)
    usage
    exit 1
    ;;
esac

echo
echo "Список:"
ollama list
echo
echo "На 6 ГБ в VRAM должна быть ОДНА модель. Проверка: ./scripts/check-gpu.sh"
