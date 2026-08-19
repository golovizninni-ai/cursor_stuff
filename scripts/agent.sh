#!/usr/bin/env bash
# Разовый прогон Aider: задача текстом, файлы в ./work
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

msg="${*:-}"
if [[ -z "$msg" ]]; then
  echo "Использование: $0 \"напиши docker-compose для sonarr radarr prowlarr\""
  exit 1
fi

if [[ ! -d work/.git ]]; then
  git -C work init -q
fi

model="${MODEL_CODER:-qwen2.5-coder:7b}"

echo "модель: ollama_chat/${model}"
echo "каталог: $ROOT/work"
echo

docker compose --profile code run --rm --no-deps \
  -e OLLAMA_API_BASE=http://ollama:11434 \
  agent \
  --model "ollama_chat/${model}" \
  --yes \
  --no-auto-commits \
  --message "$msg"
