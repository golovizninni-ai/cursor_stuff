# Песочница локальных моделей (чат, код, поиск, картинки)

Хаб на Ubuntu VM в Docker: **Open WebUI** + **Ollama** (GPU) + **SearXNG** + **LiteLLM**.
Игровые ПК в той же LAN (3060 Ti, 9070 XT) подключаются как воркеры, когда не заняты.

Это не Cursor и не Claude: 7B на 1660 Ti 6 ГБ отвечает медленнее и тупее. Зато можно крутить разные модели локально и не отдавать чаты в облако.

## Что входит

| Сервис | Зачем |
| --- | --- |
| Open WebUI `:3000` | Чат, выбор модели, веб-поиск, (опционально) картинки |
| Ollama `:11434` | Локальные LLM на 1660 Ti |
| SearXNG `:8888` | Поиск инфы для WebUI без API-ключей |
| LiteLLM `:4000` | Один OpenAI-URL для агента и fallback на воркеры |
| ComfyUI `:8188` (профиль `images`) | Генерация картинок, **не вместе** с 7B на 6 ГБ |
| Aider (профиль `code`) | «Напиши compose…» → файлы в `work/` |

## Железо (ожидания)

| Машина | GPU | Текст | Картинки |
| --- | --- | --- | --- |
| Этот хаб | 1660 Ti **6 ГБ** | 3B спокойно, 7B с ctx 4k | SD 1.5 / turbo |
| Windows | 3060 Ti 8 ГБ | 7B комфортно | SDXL впритык |
| AMD | 9070 XT **16 ГБ** | 14B | SDXL / пробовать Flux |

На 6 ГБ **по очереди**: Immich ML, большая LLM, ComfyUI. NVENC у Jellyfin обычно мешает меньше. Если считает 9070 XT — хаб и Immich можно не трогать.

Подробнее: [docs/models.md](docs/models.md), [docs/workers.md](docs/workers.md), [docs/gpu.md](docs/gpu.md).

## Развёртывание на Ubuntu VM

Требования: Ubuntu LTS, Docker **не из Snap**, проброшенная NVIDIA, драйвер **550+**, диск **50+ ГБ**, лучше **8 ГБ swap**.

```bash
sudo git clone <этот-репозиторий> /opt/local-ai   # или положите файлы как удобно
cd /opt/local-ai          # каталог с docker-compose.yml
chmod +x scripts/*.sh

# 1) GPU в Docker (один раз, нужен sudo)
sudo ./scripts/install-nvidia-toolkit.sh

# 2) .env, секреты, проверка nvidia-smi / swap
./scripts/install-host.sh

# 3) хаб
./scripts/up.sh

# 4) модели (долго, гигабайты)
./scripts/pull-models.sh core
./scripts/check-gpu.sh
```

Откройте `http://<ip-виртуалки>:3000`. **Первый зарегистрированный пользователь — админ.** Включите пароль (он уже включён в compose).

Порты по умолчанию слушают `0.0.0.0` (LAN). Не пробрасывайте 11434/3000 в интернет. Ограничьте firewall домашней подсетью.

### Поиск в чате

Admin → Settings → Web Search: движок SearXNG, URL уже задан переменными compose. В чате включите web search (иконка поиска / в настройках модели).

SearXNG отдельно: `http://<ip>:8888`.

### Код

В WebUI выберите `qwen2.5-coder:7b` или `qwen2.5-coder:7b-6gb`.

Агент в песочнице (не в боевой папке arr/Immich):

```bash
./scripts/agent.sh "напиши docker-compose для sonarr radarr prowlarr qbittorrent"
ls -la work/
```

### Картинки

```bash
./scripts/up-images.sh
```

Первый старт ComfyUI качает много. На 1660 Ti кладите checkpoint SD 1.5 в `data/comfyui/` (путь зависит от образа, часто `data/comfyui/ComfyUI/models/checkpoints`). В WebUI: Admin → Images → engine ComfyUI, URL `http://comfyui:8188`. Вернуть чат: `docker compose start ollama && docker compose --profile images stop comfyui`.

## Воркеры в LAN

В `.env`:

```bash
OLLAMA_WORKER_XT=http://192.168.1.50:11434
OLLAMA_WORKER_3060=http://192.168.1.40:11434
```

Потом `./scripts/render-litellm.sh && docker compose up -d litellm`.

В WebUI появятся OpenAI-модели `chat` / `coder` (сначала XT, потом 3060, потом хаб). Если ПК выключен — пауза несколько секунд и ответ с 1660 Ti.

Как поднять Ollama на Windows и AMD: [docs/workers.md](docs/workers.md).

## Полезные команды

```bash
docker compose logs -f open-webui ollama
docker compose exec ollama ollama ps
docker compose exec ollama ollama stop qwen2.5:7b   # освободить VRAM
./scripts/down.sh
```

## Структура

```
docker-compose.yml
.env.example
scripts/          install-host, up, pull-models, agent, check-gpu, …
modelfiles/       короткий ctx для 6 ГБ
searxng/          settings.yml (json для WebUI)
litellm/          сгенерированный роутер
work/             файлы Aider
docs/
```
