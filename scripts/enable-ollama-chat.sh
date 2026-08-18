#!/usr/bin/env bash
# Опция: интерактивный чат playerbots через Ollama (GPU на ВМ).
# Только вариант playerbots. npcbots/lonewolf не поддерживаются.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

VARIANT="${1:-playerbots}"
[[ "$VARIANT" == "playerbots" ]] || die "Ollama-чат только у playerbots (не $VARIANT)"
variant_paths "$VARIANT"
[[ -d "$SRC" ]] || die "сначала scripts/install.sh playerbots или scripts/install-docker.sh playerbots"

MODEL="${OLLAMA_MODEL:-qwen2.5:3b}"
MARKER="$AC_ROOT/$VARIANT/ollama-chat"
MODE="$(read_install_mode "$VARIANT")"

clone_or_update() {
  local url="$1" dest="$2" branch="${3:-}"
  if [[ -d "$dest/.git" ]]; then
    log "Обновление $dest"
    git -C "$dest" fetch --depth 1 origin
    if [[ -n "$branch" ]]; then
      git -C "$dest" checkout "$branch"
      git -C "$dest" pull --ff-only origin "$branch" || true
    else
      git -C "$dest" pull --ff-only || true
    fi
  else
    log "Клон $url → $dest"
    if [[ -n "$branch" ]]; then
      git clone --depth 1 --branch "$branch" "$url" "$dest"
    else
      git clone --depth 1 "$url" "$dest"
    fi
  fi
}

log "GPU (проброс 1660 Ti / позже 3070 Ti)"
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=name,memory.total --format=csv,noheader || true
else
  log "предупреждение: nvidia-smi нет — Ollama может уйти на CPU (медленно). Проверьте проброс видеокарты в ВМ."
fi

log "libfmt-dev для сборки модуля"
$SUDO apt-get update -qq
$SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y libfmt-dev curl ca-certificates

log "модуль DustinHendrickson/mod-ollama-chat"
mkdir -p "$SRC/modules"
clone_or_update https://github.com/DustinHendrickson/mod-ollama-chat.git \
  "$SRC/modules/mod-ollama-chat" master
printf '%s\n' "$MODEL" >"$MARKER"

if ! command -v ollama >/dev/null 2>&1; then
  log "установка Ollama на хост ВМ (не в compose *arr)"
  curl -fsSL https://ollama.com/install.sh | $SUDO sh
fi

DROPIN_DIR="/etc/systemd/system/ollama.service.d"
$SUDO mkdir -p "$DROPIN_DIR"
HOST_BIND="127.0.0.1:11434"
if [[ "$MODE" == "docker" ]]; then
  HOST_BIND="0.0.0.0:11434"
  log "Docker-worldserver ходит на хост: Ollama слушает 0.0.0.0:11434 (не пробрасывайте 11434 друзьям)"
fi
$SUDO tee "$DROPIN_DIR/acore.conf" >/dev/null <<EOF
[Service]
Environment="OLLAMA_HOST=${HOST_BIND}"
Environment="OLLAMA_KEEP_ALIVE=30m"
EOF
$SUDO systemctl daemon-reload
$SUDO systemctl enable --now ollama
$SUDO systemctl restart ollama
sleep 2

log "модель $MODEL (1660 Ti 6 ГБ → qwen2.5:3b; 3070 Ti → qwen2.5:7b)"
ollama pull "$MODEL"

apply_conf() {
  local conf="$1"
  [[ -f "$conf" ]] || return 0
  python3 "$SCRIPT_DIR/apply_overlay.py" "$conf" "$REPO_ROOT/configs/playerbots/mod_ollama_chat.overlay.conf"
  local extra
  extra="$(mktemp)"
  printf 'OllamaChat.Model = %s\n' "$MODEL" >"$extra"
  if [[ "$MODE" == "docker" ]]; then
    printf 'OllamaChat.Url = http://host.docker.internal:11434/api/generate\n' >>"$extra"
  fi
  python3 "$SCRIPT_DIR/apply_overlay.py" "$conf" "$extra"
  rm -f "$extra"
}

copy_and_overlay_module_conf() {
  local dest="$1"
  local dist="$SRC/modules/mod-ollama-chat/conf/mod_ollama_chat.conf.dist"
  [[ -f "$dist" ]] || die "нет $dist"
  mkdir -p "$(dirname "$dest")"
  if [[ ! -f "$dest" ]]; then
    cp "$dist" "$dest"
  fi
  apply_conf "$dest"
}

log "остановка world на время пересборки"
"$SCRIPT_DIR/stop.sh" "$VARIANT" || true

if [[ "$MODE" == "docker" ]]; then
  DF="$SRC/apps/docker/Dockerfile"
  if [[ -f "$DF" ]] && ! grep -q libfmt-dev "$DF"; then
    log "в Dockerfile образа добавляю libfmt-dev"
    sed -i 's/libncurses5-dev liblzma-dev/libncurses5-dev liblzma-dev libfmt-dev/' "$DF" || true
  fi
  sed "s/qwen2.5:3b/${MODEL}/g" "$REPO_ROOT/docker/compose.ollama.yml" >"$SRC/docker-compose.ollama.yml"
  copy_and_overlay_module_conf "$SRC/env/dist/etc/modules/mod_ollama_chat.conf"
  log "пересборка образа worldserver (модуль компилируется внутрь)"
  dc build ac-worldserver ac-db-import
  "$SCRIPT_DIR/start.sh" "$VARIANT"
else
  log "нативная пересборка"
  "$SCRIPT_DIR/03-build.sh" "$VARIANT"
  "$SCRIPT_DIR/04-configure.sh" "$VARIANT"
  copy_and_overlay_module_conf "$PREFIX/etc/modules/mod_ollama_chat.conf"
  if [[ -f "$PREFIX/etc/playerbots.conf" ]]; then
    python3 "$SCRIPT_DIR/apply_overlay.py" "$PREFIX/etc/playerbots.conf" \
      "$REPO_ROOT/configs/playerbots/playerbots-ollama.overlay.conf"
  fi
  "$SCRIPT_DIR/start.sh" "$VARIANT"
fi

echo
log "готово. В игре шепните боту по-русски; в группе — обычный /p (не команды follow/attack)."
echo "  модель: $MODEL"
echo "  проверка: curl -s http://127.0.0.1:11434/api/tags"
echo "  ГМ: .ollama reload"
echo "  после 3070 Ti: OLLAMA_MODEL=qwen2.5:7b $0 playerbots"
echo "Документация: docs/ollama-chat.md"
