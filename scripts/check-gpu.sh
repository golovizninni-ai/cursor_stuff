#!/usr/bin/env bash
# Проверка: карта видна, Ollama не на CPU, кто ещё ест GPU.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> хост nvidia-smi"
if command -v nvidia-smi >/dev/null; then
  nvidia-smi --query-gpu=name,memory.total,memory.used,utilization.gpu --format=csv
  echo
  nvidia-smi --query-compute-apps=pid,process_name,used_gpu_memory --format=csv || true
else
  echo "nvidia-smi нет на хосте"
fi

echo
echo "==> GPU внутри контейнера ollama"
if docker compose ps --status running --services 2>/dev/null | grep -qx ollama; then
  docker compose exec -T ollama nvidia-smi -L 2>/dev/null || \
    docker compose exec -T ollama sh -c 'command -v nvidia-smi >/dev/null && nvidia-smi -L' || \
    echo "nvidia-smi в контейнере нет — проброс GPU, скорее всего, не работает"
  echo
  echo "==> ollama ps (процессор должен быть GPU, не CPU)"
  docker compose exec -T ollama ollama ps || true
else
  echo "контейнер ollama не запущен"
fi

echo
echo "На 6 ГБ не держите сразу: Immich ML + LLM 7B + ComfyUI."
echo "Если used memory ~6GB и есть python Immich — стопните ML на время чата."
