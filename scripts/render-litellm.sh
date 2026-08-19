#!/usr/bin/env bash
# Собирает litellm/config.generated.yaml из .env.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

MODEL_CHAT="${MODEL_CHAT:-qwen2.5:7b}"
MODEL_CODER="${MODEL_CODER:-qwen2.5-coder:7b}"
MODEL_CHAT_SMALL="${MODEL_CHAT_SMALL:-qwen2.5:3b}"
MODEL_CODER_SMALL="${MODEL_CODER_SMALL:-qwen2.5-coder:3b}"
MODEL_CHAT_XT="${MODEL_CHAT_XT:-qwen2.5:14b}"
MODEL_CODER_XT="${MODEL_CODER_XT:-qwen2.5-coder:14b}"
OLLAMA_WORKER_XT="${OLLAMA_WORKER_XT:-}"
OLLAMA_WORKER_3060="${OLLAMA_WORKER_3060:-}"

out="$ROOT/litellm/config.generated.yaml"
mkdir -p "$ROOT/litellm"

yaml_model() {
  local name="$1" model="$2" base="$3" timeout="$4"
  cat <<EOF
  - model_name: ${name}
    litellm_params:
      model: ollama_chat/${model}
      api_base: ${base}
      api_key: fake
      timeout: ${timeout}
EOF
}

yaml_list() {
  local first=1
  echo -n "["
  for x in "$@"; do
    [[ $first -eq 1 ]] || echo -n ", "
    echo -n "$x"
    first=0
  done
  echo "]"
}

chat_names=()
coder_names=()

{
  echo "model_list:"
  yaml_model "qwen-chat" "$MODEL_CHAT" "http://ollama:11434" "600"
  yaml_model "qwen-coder" "$MODEL_CODER" "http://ollama:11434" "600"
  yaml_model "qwen-chat-small" "$MODEL_CHAT_SMALL" "http://ollama:11434" "600"
  yaml_model "qwen-coder-small" "$MODEL_CODER_SMALL" "http://ollama:11434" "600"

  if [[ -n "$OLLAMA_WORKER_XT" ]]; then
    yaml_model "xt-chat" "$MODEL_CHAT_XT" "${OLLAMA_WORKER_XT%/}" "6"
    yaml_model "xt-coder" "$MODEL_CODER_XT" "${OLLAMA_WORKER_XT%/}" "6"
    chat_names+=("xt-chat")
    coder_names+=("xt-coder")
  fi
  if [[ -n "$OLLAMA_WORKER_3060" ]]; then
    yaml_model "w3060-chat" "$MODEL_CHAT" "${OLLAMA_WORKER_3060%/}" "6"
    yaml_model "w3060-coder" "$MODEL_CODER" "${OLLAMA_WORKER_3060%/}" "6"
    chat_names+=("w3060-chat")
    coder_names+=("w3060-coder")
  fi
  chat_names+=("qwen-chat")
  coder_names+=("qwen-coder")

  cat <<EOF

litellm_settings:
  drop_params: true
  request_timeout: 600

router_settings:
  routing_strategy: simple-shuffle
  num_retries: 0
  allowed_fails: 1
  cooldown_time: 45
  model_group_alias:
    chat: ${chat_names[0]}
    coder: ${coder_names[0]}
EOF

  if [[ ${#chat_names[@]} -gt 1 ]]; then
    echo "  fallbacks:"
    # цепочка: каждый уровень падает на оставшихся
    local_i=0
    for ((i = 0; i < ${#chat_names[@]} - 1; i++)); do
      rest=("${chat_names[@]:i+1}")
      echo "    - ${chat_names[i]}: $(yaml_list "${rest[@]}")"
    done
    for ((i = 0; i < ${#coder_names[@]} - 1; i++)); do
      rest=("${coder_names[@]:i+1}")
      echo "    - ${coder_names[i]}: $(yaml_list "${rest[@]}")"
    done
  fi
} >"$out"

echo "записан $out"
echo "приоритет chat: ${chat_names[*]}"
echo "приоритет coder: ${coder_names[*]}"
