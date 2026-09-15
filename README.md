# cursor_stuff

Черновики и эксперименты Cursor.

## Проекты в этом репозитории

| Ветка | Описание |
|-------|----------|
| [`azerothcore-progressive`](https://github.com/golovizninni-ai/cursor_stuff/tree/azerothcore-progressive) | Деплой AzerothCore 3.3.5a (playerbots / npcbots / lonewolf): native или Docker, Individual Progression, AHBot, AutoBalance, опции Ollama и HD-клиента |
| [`tdarr-hevc`](https://github.com/golovizninni-ai/cursor_stuff/tree/tdarr-hevc) | Tdarr HEVC + mux озвучек для аниме: hardlink-скрипт `flatten.py`, Docker Compose, NVENC под GTX 1660 Ti (профиль 3070 Ti на потом) |

Клон только ветки AzerothCore:

```bash
git clone -b azerothcore-progressive --single-branch \
  https://github.com/golovizninni-ai/cursor_stuff.git ~/azerothcore-deploy
cd ~/azerothcore-deploy
```

Клон только ветки Tdarr HEVC:

```bash
git clone -b tdarr-hevc --single-branch \
  https://github.com/golovizninni-ai/cursor_stuff.git ~/tdarr-hevc
cd ~/tdarr-hevc
```

## Прочее

SOC TV / DietPi dashboard перенесён в приватный репозиторий:

- https://github.com/golovizninni-ai/vls-stuff/tree/diet-pi-dashboard
