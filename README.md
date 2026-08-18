# AzerothCore 3.3.5a: прогрессия, боты, аукцион

Набор для **Ubuntu 22.04/24.04 LTS**. Debian-ВМ не нужна.

## Как ставить (выберите один путь)

| | Команда | Когда |
|---|---|---|
| **A. Нативно** | `./scripts/install.sh playerbots` | clang + MySQL + systemd на хосте |
| **B. Docker** | `./scripts/install-docker.sh playerbots` | рядом с *arr, без MySQL/clang на хосте |

Дальше один и тот же вход: `./scripts/start.sh` / `stop.sh` (смотрит маркер `install-mode`).

- Нативно: [docs/install-native.md](docs/install-native.md)
- Docker: [docs/install-docker.md](docs/install-docker.md) и [docker/README.md](docker/README.md)

Не смешивайте оба пути на одном варианте (`playerbots` / `npcbots` / `lonewolf`).

Три игровых стека (порты 3724/8085, одновременно только один):

| Вариант | Для кого |
|---------|----------|
| **playerbots** | ~200 ботов в `/who`, рейд по инвайту, AutoBalance если состав неполный |
| **npcbots** | вы + 4 спутника, рейды впятером |
| **lonewolf** | без ИИ, 1–3 живых игрока + AutoBalance |

Общее: Individual Progression, все профессии, AHBot, русский клиент.

## Железо

- playerbots, 200 ботов: от **16 ГБ RAM** (с *arr в Docker — теснее, уменьшите число ботов).
- npcbots / lonewolf: обычно **8 ГБ**.

Клиент **3.3.5a (12340)** на Bazzite. MPQ в репозиторий не кладём.

## Русификация

Русский клиент. На сервере: `RealmZone = 12`, `SupportedLocales = 0,8`, **DBC enUS**. Квесты из БД частично на английском. Команды ботов английские.

## Запуск и остановка

[docs/service.md](docs/service.md)

```bash
./scripts/start.sh playerbots
./scripts/status.sh
./scripts/stop.sh
./scripts/enable-autostart.sh playerbots
```

Не `kill -9`. Docker: аккаунт через `docker attach ac-playerbots-worldserver` (Ctrl+P Ctrl+Q). Native первый раз — tmux.

AHBot и IP реалма:

```bash
./scripts/setup-ahbot.sh playerbots <account_id> <guid>
./scripts/set-realm-address.sh playerbots <IP_ВМ>
```

## Профессии и боты

`MaxPrimaryTradeSkill = 11`, лишние профессии — макрос `/cast Enchanting`.

Playerbots: `.playerbots bot addclass warrior`, `/p follow`. NPCBots: gossip / `.npcbot`. Lonewolf: без ИИ.

Аддоны: [docs/addons.md](docs/addons.md). ConsolePort на Bazzite: [docs/consoleport.md](docs/consoleport.md). HD-модели (опция): [docs/visuals.md](docs/visuals.md). Живой чат ботов (опция, playerbots): [docs/ollama-chat.md](docs/ollama-chat.md).

## Админ-команды в игре

В чате с точки, gmlevel 3. Аккаунт другу — консоль worldserver (`account create`).

Примеры: `.gm on`, `.teleport Stormwind`, `.ip set 6`, `.playerbots bot addclass warrior`, `.npcbot spawn 70001`.

Полный список под этот стек: [docs/gm-commands.md](docs/gm-commands.md).

## Клиент и порты для друзей

`Data/ruRU/realmlist.wtf`: `set realmlist IP_ВМ`

Проброс: **TCP 3724** и **8085**. MySQL наружу не открывать. [docs/ports.md](docs/ports.md).

Data для **native**: [desktop/README.md](desktop/README.md). Для **Docker** карты качает контейнер сам.

## Опция: живой чат ботов (Ollama)

Только **playerbots**. На ВМ с проброшенной **1660 Ti** (потом 3070 Ti): боты отвечают по-русски на шепот и `/p`.

```bash
./scripts/enable-ollama-chat.sh playerbots
```

1660 Ti 6 ГБ → `qwen2.5:3b`. После 3070 Ti: `OLLAMA_MODEL=qwen2.5:7b ./scripts/enable-ollama-chat.sh playerbots`.

Порт 11434 наружу не открывать. Подробности: [docs/ollama-chat.md](docs/ollama-chat.md).

## Опция: красивее модели и текстуры

Не обязательно. Только клиент на Bazzite, сервер не пересобирать. На [загрузках ChromieCraft](https://chromiecraft.com/en/downloads/) есть **HD Patch** (файлы в `Data/`) и **Alternative HD Patch** с установщиком `patchmenu.exe`: модели становятся современнее, обновляется часть текстур.

Полная инструкция для Lutris/Bottles/Proton: [docs/visuals.md](docs/visuals.md). После патча realmlist должен остаться **ваш IP**, не реалм ChromieCraft.
