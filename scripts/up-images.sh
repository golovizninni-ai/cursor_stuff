#!/usr/bin/env bash
# Поднять ComfyUI. На 6 ГБ выгрузите LLM: этот скрипт останавливает ollama на время.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Останавливаю ollama, чтобы освободить VRAM для картинок..."
docker compose stop ollama || true
docker compose --profile images up -d comfyui
echo "ComfyUI: http://$(hostname -I 2>/dev/null | awk '{print $1}'):${COMFYUI_PORT:-8188}"
echo "В Open WebUI: Admin → Settings → Images → ComfyUI, URL http://comfyui:8188 (из Docker-сети)"
echo "Вернуть чат: docker compose start ollama && docker compose --profile images stop comfyui"
