# GPU на хабе рядом с Immich и arr

1660 Ti 6 ГБ. VRAM **не делится** как CPU: два больших потребителя → OOM или LLM на CPU (тогда чат бесполезен).

## Кто ест карту

| Процесс | Насколько мешает LLM |
| --- | --- |
| Immich `machine-learning` (лица, CLIP) | Сильно — стопайте на время 7B / ComfyUI |
| Jellyfin/Plex **NVENC** | Обычно слабо |
| Tdarr / полный перекод | Мешает, не параллельте с 7B |
| ComfyUI | Занимает карту целиком на 6 ГБ |
| Ollama 7B | ~4.5–5.5 ГБ + KV-cache |

## Как жить

1. По умолчанию Ollama с `OLLAMA_KEEP_ALIVE=5m` сама выгружает веса.
2. Принудительно: `docker compose exec ollama ollama stop qwen2.5:7b` (подставьте имя из `ollama ps`).
3. На время длинного чата 7B:

   ```bash
   docker compose -f /путь/к/immich/docker-compose.yml stop immich-machine-learning
   ```

   Имя сервиса смотрите в своём Immich-стеке (`immich-machine-learning` / `immich_ml`).

4. Картинки: `./scripts/up-images.sh` сам останавливает контейнер ollama.
5. Перед работой: `./scripts/check-gpu.sh` — в `ollama ps` процессор **GPU**, не CPU.

## Если считает воркер (3060 / XT)

Локальную 1660 Ti можно отдать Immich. В WebUI берите модели `chat` / `coder` через LiteLLM, не локальный `qwen2.5:7b`.

## Апгрейд VM (32 ГБ RAM + 3070 Ti 8 ГБ)

Хаб перестанет задыхаться, 7B станет запасным без драмы. Для качества агента/14B по-прежнему выгоднее **9070 XT 16 ГБ**, когда ПК свободен: 8 ГБ на сервере не догонят 16 ГБ на XT.
