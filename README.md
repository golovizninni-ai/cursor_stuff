# AzerothCore 3.3.5a: прогрессия, боты, аукцион

Личный сервер WoW **3.3.5a (12340)** на **Ubuntu 22.04/24.04 LTS**.  
Клиент — на **Bazzite** (не Windows). Debian-ВМ не нужна.

Этот репозиторий — скрипты деплоя. Клонируйте его на ВМ, например в `~/azerothcore-deploy`.

---

## 1. Что получите

| Вариант | Для кого | ИИ-боты |
|---------|----------|---------|
| **playerbots** | ~200 ботов в `/who`, рейд по инвайту | да (отдельный форк) |
| **npcbots** | вы + до 4 нанятых спутников | да (NPCBots) |
| **lonewolf** | 1–3 живых игрока / друзья | нет |

У всех: **Individual Progression** (тиры на персонаже), все профессии на одном чаре, **AHBot**, **AutoBalance**, русский клиент.

Одновременно на портах **3724/8085** крутится **только один** вариант.

---

## 2. Выберите путь установки

| | Команда | Когда брать |
|---|---|---|
| **A. Нативно** | `./scripts/install.sh <вариант>` | clang + MySQL + systemd на хосте |
| **B. Docker** | `./scripts/install-docker.sh <вариант>` | рядом с *arr, без MySQL/clang на хосте |

Дальше один вход: `start.sh` / `stop.sh` / `status.sh` (смотрит `~/azerothcore-servers/<вариант>/install-mode`).

Не смешивайте native и Docker **на одном** варианте. Не кладите AzerothCore в compose Sonarr/Radarr.

Подробнее: [docs/install-native.md](docs/install-native.md), [docs/install-docker.md](docs/install-docker.md).

---

## 3. Железо

- **playerbots**, 200 ботов: от **16 ГБ RAM** (с *arr теснее — уменьшите число ботов в конфиге).
- **npcbots / lonewolf**: обычно **8 ГБ** (в Docker у world `mem_limit` 4g, у playerbots 8g).
- Диск: десятки ГБ под исходники, образы и client-data.
- GPU (опция чата Ollama): проброшенная **1660 Ti** / позже **3070 Ti**.

---

## 4. Пошагово: Docker + lonewolf (типичный случай с *arr)

Если недавно ставили Docker и world уходил в **Restarting** — см. [§9](#9-если-контейнеры-есть-а-startsh-не-держит-сервис). Ниже — актуальный порядок.

### 4.1. Подготовка ВМ

```bash
sudo apt update
sudo apt install -y git curl ca-certificates
# docker и compose уже должны быть (как у *arr)
docker compose version
```

```bash
git clone <этот-репозиторий> ~/azerothcore-deploy
cd ~/azerothcore-deploy
```

### 4.2. Установка

Долго (клон + сборка образов + скачивание карт enUS).

```bash
./scripts/install-docker.sh lonewolf
```

Скрипт:

1. Клонирует официальный `azerothcore-wotlk` + модули (IP, AHBot, AutoBalance).
2. Останавливает **другие** варианты целиком (включая их MySQL на 13306).
3. Пишет `.env` и `docker-compose.override.yml`.
4. `docker compose up -d --build`.
5. Ждёт, пока world/auth стабильны.
6. Применяет `configs/*.overlay.conf` и ставит **`Updates.EnableDatabases = 0`** на world (миграции только в `ac-db-import`).
7. Рестартит world и снова проверяет здоровье.

Каталоги:

- исходники: `~/azerothcore-servers/lonewolf/src/`
- маркер: `~/azerothcore-servers/lonewolf/install-mode` → `docker`
- пароль БД: `~/azerothcore-servers/mysql-password` (и в `.env`)

### 4.3. Аккаунт ГМ

```bash
docker attach ac-lonewolf-worldserver
```

В консоли worldserver (без точки):

```
account create МойЛогин МойПароль
account set gmlevel МойЛогин 3 -1
```

Отцепиться: **Ctrl+P**, затем **Ctrl+Q**. Не Ctrl+C — это убьёт процесс в контейнере с TTY.

### 4.4. IP реалма (чтобы клиент не шёл на 127.0.0.1)

```bash
./scripts/set-realm-address.sh lonewolf 192.168.x.x
# или белый IP / Tailscale
```

### 4.5. Обычный день

```bash
./scripts/start.sh lonewolf
./scripts/status.sh
./scripts/stop.sh          # world+auth; БД этого варианта остаётся
./scripts/enable-autostart.sh lonewolf
```

Друзьям проброс: **TCP 3724** и **8085**. MySQL (3306/13306) наружу не открывать. [docs/ports.md](docs/ports.md).

### 4.6. Клиент на Bazzite

1. WoW **3.3.5a build 12340**, язык **ruRU**, в Lutris / Bottles / Proton.
2. В префиксе игры: `Data/ruRU/realmlist.wtf` → `set realmlist IP_ВМ`
3. Аддоны: [docs/addons.md](docs/addons.md). Геймпад: [docs/consoleport.md](docs/consoleport.md).

Для Docker карты с клиента снимать не нужно — их качает `ac-client-data-init`.

---

## 5. Пошагово: нативно (без Docker для AC)

```bash
./scripts/install.sh playerbots   # или npcbots / lonewolf
```

Пакеты, MySQL 8, клон, cmake, systemd. Затем data:

- либо архив enUS → `scripts/import-data.sh`
- либо экстракт с Bazzite → [desktop/README.md](desktop/README.md)

Первый импорт SQL — **tmux** + ручной `worldserver`, не сразу systemd. Дальше `start.sh`. Подробнее: [docs/install-native.md](docs/install-native.md), [docs/service.md](docs/service.md).

---

## 6. После входа в игру

- ГМ: `.gm on`, `.teleport Stormwind`, `.ip set 6` — [docs/gm-commands.md](docs/gm-commands.md)
- Профессии: `MaxPrimaryTradeSkill = 11`, лишние — макрос `/cast Enchanting`
- **playerbots:** `.playerbots bot addclass warrior`, в `/p`: `follow`, `attack`
- **npcbots:** `.npcbot spawn` / gossip найма
- **lonewolf:** без ИИ, сложность режет AutoBalance
- AHBot: создайте персонажа-заглушку, зайдите один раз, затем  
  `./scripts/setup-ahbot.sh <вариант> <account_id> <guid>`

---

## 7. Опции

### Живой чат ботов (Ollama) — только playerbots

На ВМ с GPU:

```bash
./scripts/enable-ollama-chat.sh playerbots
```

1660 Ti 6 ГБ → `qwen2.5:3b`. После 3070 Ti:  
`OLLAMA_MODEL=qwen2.5:7b ./scripts/enable-ollama-chat.sh playerbots`  
Порт **11434** друзьям не открывать. [docs/ollama-chat.md](docs/ollama-chat.md).

### HD-модели / текстуры (клиент)

Патчи ChromieCraft (`HD Patch` или `patchmenu.exe`) только на Bazzite. Realmlist после патча — **ваш IP**, не ChromieCraft. [docs/visuals.md](docs/visuals.md).

---

## 8. Если установка оборвалась (ваши логи: playerbots / lonewolf)

Типичные ошибки:

| Симптом | Причина | Что делать |
|---------|---------|------------|
| `нет systemd-юнита ac-playerbots-world` | Только клон исходников, без `install.sh` | `./scripts/install.sh playerbots` или `./scripts/install-docker.sh playerbots` |
| `open .../azerothcore-deploy/docker-compose.yml: no such file` | Старая версия скриптов: compose искали в корне деплоя | `cd ~/azerothcore-deploy && git pull` (ветка `azerothcore-progressive`), затем `./scripts/install-docker.sh lonewolf` |
| `status=203/EXEC` в journalctl | Юниты systemd есть, **бинарников нет** (сборка не прошла) | Остановить цикл (ниже), затем **один** путь: `install.sh` или `install-docker.sh` |

Диагностика на ВМ:

```bash
cd ~/azerothcore-deploy
git pull   # ветка azerothcore-progressive
./scripts/doctor.sh lonewolf
```

Остановить restart-loop native (если `203/EXEC`):

```bash
systemctl --user stop ac-lonewolf-auth.service ac-lonewolf-world.service
systemctl --user disable ac-lonewolf-auth.service ac-lonewolf-world.service
```

Дальше **не** смешивайте пути на одном варианте — выберите Docker **или** native и доведите установку до конца:

```bash
# Docker (рядом с *arr, без clang на хосте):
./scripts/install-docker.sh lonewolf

# Native (clang + MySQL на хосте):
./scripts/install.sh lonewolf
```

Актуальный `start.sh` перед systemd проверяет бинарники и не даёт уйти в бесконечный `203/EXEC`.

---

## 9. Если контейнеры есть, а `start.sh` не держит сервис

Симптом: `docker ps` показывает `ac-lonewolf-*`, у world статус **Restarting**, после `start.sh` снова падает.

### 8.1. Смотрите лог

```bash
docker logs --tail 200 ac-lonewolf-worldserver
./scripts/status.sh lonewolf
```

### 8.2. Частые причины (и что сделано в скриптах)

| Причина | Что происходит | Что делать |
|---------|----------------|------------|
| **Updates=7 на world** | Повторный SQL после db-import → краш | Актуальный `start.sh` / `install-docker.sh` ставят Updates=0. Или вручную в `~/azerothcore-servers/lonewolf/src/env/dist/etc/worldserver.conf` |
| **Порт 13306 занят** другим вариантом | DB другого стека жива после `stop.sh` | Актуальный `start.sh` глушит чужие world+auth+**database**. Или `docker stop ac-playerbots-database` и т.п. |
| **3724/8085 заняты** | другой AC / старый контейнер | `docker ps --filter name=ac-` и остановить лишнее |
| **OOM** | `mem_limit` 8g на lonewolf при 8 ГБ ВМ + *arr | Сейчас у lonewolf/npcbots **4g**. Смотрите `dmesg \| grep -i oom` |
| **Нет карт** | client-data-init не докачал | `docker logs ac-lonewolf-client-data` |
| **db-import упал** | модульный SQL | `docker logs ac-lonewolf-db-import` |

Переустановка поверх (сохранит volume БД, пересоберёт override):

```bash
cd ~/azerothcore-deploy
./scripts/install-docker.sh lonewolf
```

Полный снос контейнеров варианта (данные MySQL volume останутся, пока не `down -v`):

```bash
cd ~/azerothcore-servers/lonewolf/src
docker compose -p ac-lonewolf down
# осторожно, удалит БД варианта:
# docker compose -p ac-lonewolf down -v
```

---

## 10. Русификация

Русский клиент. На сервере: `RealmZone = 12`, `SupportedLocales = 0,8`, **DBC enUS**. Квесты из БД частично на английском. Команды playerbots — английские.

---

## 11. Карта файлов

| Путь | Назначение |
|------|------------|
| `scripts/install-docker.sh` | Docker-установка |
| `scripts/install.sh` | Нативная установка |
| `scripts/start.sh` `stop.sh` `status.sh` | День за днём |
| `scripts/doctor.sh` | Диагностика после сбоя установки |
| `scripts/docker-apply-overlays.sh` | configs → Docker etc + Updates=0 |
| `scripts/set-realm-address.sh` | IP в realmlist БД |
| `scripts/setup-ahbot.sh` | Включить продавца/покупателя АН |
| `configs/` | Overlay-конфиги (native + docker) |
| `docs/` | Узкие гайды |

Не `kill -9` на worldserver — сначала сейв персонажей.
