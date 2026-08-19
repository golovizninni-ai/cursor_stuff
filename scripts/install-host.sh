#!/usr/bin/env bash
# Подготовка Ubuntu VM: Docker GPU, swap, .env, каталоги.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

echo "==> каталоги"
mkdir -p data/ollama data/open-webui data/comfyui work searxng litellm
touch work/.gitkeep

if [[ ! -f .env ]]; then
  cp .env.example .env
  if need_cmd openssl; then
    secret="$(openssl rand -hex 24)"
    searx="$(openssl rand -hex 24)"
    master="sk-$(openssl rand -hex 16)"
    sed -i "s/^WEBUI_SECRET_KEY=.*/WEBUI_SECRET_KEY=${secret}/" .env
    sed -i "s/^SEARXNG_SECRET=.*/SEARXNG_SECRET=${searx}/" .env
    sed -i "s/^LITELLM_MASTER_KEY=.*/LITELLM_MASTER_KEY=${master}/" .env
    echo "==> секреты записаны в .env"
  else
    echo "!! openssl нет — смените WEBUI_SECRET_KEY / SEARXNG_SECRET в .env вручную"
  fi
else
  echo "==> .env уже есть, не трогаю"
fi

echo "==> NVIDIA"
if ! need_cmd nvidia-smi; then
  echo "!! nvidia-smi не найден. В госте поставьте проприетарный драйвер 550+ и пробросьте GPU в VM."
  echo "   После драйвера: sudo apt install -y nvidia-container-toolkit && sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker"
  exit 1
fi
nvidia-smi -L || true

echo "==> Docker"
if ! need_cmd docker; then
  echo "!! Docker не установлен. На Ubuntu:"
  echo "   curl -fsSL https://get.docker.com | sudo sh"
  echo "   sudo usermod -aG docker \"\$USER\"  &&  newgrp docker"
  exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "!! Нужен плагин docker compose v2 (не snap-docker)."
  exit 1
fi

if docker info 2>/dev/null | grep -qi snap; then
  echo "!! Похоже Docker из Snap — nvidia-container-toolkit с ним часто не работает. Поставьте Docker из get.docker.com"
fi

echo "==> GPU в Docker"
if docker info 2>/dev/null | grep -qi nvidia; then
  echo "    runtime NVIDIA уже виден"
else
  echo "    runtime NVIDIA не виден. Если toolkit ещё не ставили:"
  echo "      curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg"
  echo "      curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \\"
  echo "        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \\"
  echo "        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list"
  echo "      sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit"
  echo "      sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker"
fi

if docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu22.04 nvidia-smi >/dev/null 2>&1; then
  echo "    docker --gpus all: OK"
else
  echo "!! Тест 'docker run --gpus all ... nvidia-smi' не прошёл."
  echo "   Пока GPU в контейнерах не заведётся, Ollama уедет на CPU."
fi

echo "==> swap (на 14 ГБ RAM лучше 8+ ГБ)"
if [[ -f /proc/meminfo ]]; then
  swap_kb="$(awk '/SwapTotal:/ {print $2}' /proc/meminfo)"
  if [[ "${swap_kb:-0}" -lt 4000000 ]]; then
    echo "!! Swap меньше 4 ГБ. Пример:"
    echo "      sudo fallocate -l 8G /swapfile && sudo chmod 600 /swapfile"
    echo "      sudo mkswap /swapfile && sudo swapon /swapfile"
    echo "      echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab"
  else
    echo "    swap: ${swap_kb} кБ"
  fi
fi

if [[ ! -d work/.git ]] && need_cmd git; then
  git -C work init -q
  echo "==> git init в work/ (для Aider)"
fi

"$ROOT/scripts/render-litellm.sh"

echo
echo "Дальше:"
echo "  docker compose up -d"
echo "  ./scripts/pull-models.sh core"
echo "  ./scripts/check-gpu.sh"
echo "Чат: http://<ip-vm>:${WEBUI_PORT:-3000}  (первый пользователь станет админом)"
