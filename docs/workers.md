# Воркеры в LAN (3060 Ti и 9070 XT)

Хаб не режет одну модель на несколько машин (по домашнему гигабиту это обычно медленнее). Каждая карта крутит **свою** Ollama. LiteLLM на хабе: жив XT → его 14B; иначе 3060 Ti 7B; иначе 1660 Ti.

Все машины в одной подсети. Порт **11434 только в LAN**, не в WAN.

## Общее

1. Поставьте Ollama, скачайте те же теги, что в `.env` хаба (`MODEL_CHAT`, `MODEL_CODER`; на XT ещё `MODEL_CHAT_XT` / `MODEL_CODER_XT`).
2. Ollama должна слушать `0.0.0.0:11434`, не только localhost.
3. С хаба: `curl http://<ip-пк>:11434/api/tags`
4. Пропишите URL в `.env` хаба, `./scripts/render-litellm.sh`, `docker compose up -d litellm`.
5. Перед игрой **остановите** Ollama (служба / трей), чтобы не драться за VRAM с игрой. Хаб сам уйдёт на fallback.

Когда воркер считает LLM, **Immich ML на 1660 Ti можно не стопать**.

## Windows + RTX 3060 Ti (NVIDIA)

1. [Ollama for Windows](https://ollama.com/download).
2. Переменные среды пользователя или системы:
   - `OLLAMA_HOST=0.0.0.0:11434`
   - `OLLAMA_KEEP_ALIVE=5m`
3. Перезапустите Ollama из трея.
4. PowerShell **от администратора**: [`scripts/windows-ollama-firewall.ps1`](../scripts/windows-ollama-firewall.ps1) (профиль Private).
5. `ollama pull qwen2.5:7b` и `ollama pull qwen2.5-coder:7b`.

Docker Desktop на Windows для текстовых моделей не обязателен.

Проверка с хаба:

```bash
curl http://192.168.x.x:11434/api/tags
```

В `.env` хаба: `OLLAMA_WORKER_3060=http://192.168.x.x:11434`

Картинки SDXL: лучше нативный ComfyUI под NVIDIA на этом ПК, не через 1660 Ti. Хаб к чужому ComfyUI можно привязать вручную в настройках WebUI (IP:8188), если откроете порт только в LAN.

## 9070 XT (AMD, 16 ГБ)

Это не CUDA. Пути разные:

**Linux (предпочтительно для стабильности):** драйвер AMD + Ollama с ROCm, если `rocminfo` видит карту. Иначе Ollama/llama.cpp через **Vulkan**.

**Windows:** смотрите текущую сборку Ollama с **Vulkan** для AMD. ROCm на Windows для этой карты может не быть. Если Ollama не видит GPU — llama.cpp + Vulkan, а в LiteLLM тогда не Ollama, а OpenAI-совместимый `llama-server` (это уже ручная правка `litellm`, в v1 хаб заточен под Ollama API).

Модели на XT:

```text
ollama pull qwen2.5:14b
ollama pull qwen2.5-coder:14b
```

Теги должны совпасть с `MODEL_CHAT_XT` / `MODEL_CODER_XT` в `.env` хаба.

В `.env`: `OLLAMA_WORKER_XT=http://192.168.x.x:11434`

Картинки на AMD сложнее NVIDIA. ComfyUI: Linux+ROCm или Windows+DirectML/Vulkan по свежим гайдам. Не ожидайте «как у CUDA из коробки».

## Имена моделей

LiteLLM не переименует тег за вас. Если на XT нет `qwen2.5:14b`, запрос `chat` быстро упадёт на 3060/хаб — это нормально, но в логах litellm будет ошибка 404.

## Не делайте

- Проброс 11434 на роутере в интернет.
- Tensor-parallel / RPC 1660+3060 «чтобы склеить 14B» — для этой схемы не нужно.
- Постоянно работающую Ollama во время игр на 8 ГБ карте.
