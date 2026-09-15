# cursor_stuff

Черновики и эксперименты Cursor.

## Проекты в этом репозитории

| Ветка | Описание |
|-------|----------|
| [`azerothcore-progressive`](https://github.com/golovizninni-ai/cursor_stuff/tree/azerothcore-progressive) | Деплой AzerothCore 3.3.5a (playerbots / npcbots / lonewolf): native или Docker, Individual Progression, AHBot, AutoBalance, опции Ollama и HD-клиента |
| [`homelab-local-ai`](https://github.com/golovizninni-ai/cursor_stuff/tree/homelab-local-ai) | Локальный AI-хаб на Ubuntu VM (Docker): Open WebUI, Ollama, SearXNG, картинки ComfyUI, агент Aider; воркеры 3060 Ti / 9070 XT в LAN |

Клон AzerothCore:

```bash
git clone -b azerothcore-progressive --single-branch \
  https://github.com/golovizninni-ai/cursor_stuff.git ~/azerothcore-deploy
cd ~/azerothcore-deploy
```

Клон локального AI-хаба:

```bash
git clone -b homelab-local-ai --single-branch \
  https://github.com/golovizninni-ai/cursor_stuff.git ~/local-ai
cd ~/local-ai
```

## Прочее

SOC TV / DietPi dashboard перенесён в приватный репозиторий:

- https://github.com/golovizninni-ai/vls-stuff/tree/diet-pi-dashboard
