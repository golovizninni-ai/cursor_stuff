#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi
[[ -f .env ]] || { echo "Нет .env — сначала ./scripts/install-host.sh"; exit 1; }
./scripts/render-litellm.sh
docker compose up -d
echo "Чат: http://$(hostname -I 2>/dev/null | awk '{print $1}'):${WEBUI_PORT:-3000}"
echo "Поиск (SearXNG): http://$(hostname -I 2>/dev/null | awk '{print $1}'):${SEARXNG_PORT:-8888}"
