#!/usr/bin/env bash
# Локальные теги с коротким контекстом под 6 ГБ VRAM.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! docker compose ps --status running --services 2>/dev/null | grep -qx ollama; then
  echo "Сначала: docker compose up -d ollama"
  exit 1
fi

create() {
  local tag="$1" file="$2"
  echo "==> ollama create $tag"
  docker compose exec -T ollama ollama create "$tag" -f "/modelfiles/${file}"
}

create "qwen2.5:7b-6gb" "qwen2.5-7b-6gb.Modelfile"
create "qwen2.5-coder:7b-6gb" "qwen2.5-coder-7b-6gb.Modelfile"
echo "Готово. В WebUI можно выбрать теги *-6gb (num_ctx 4096)."
