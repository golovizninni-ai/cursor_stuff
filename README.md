# AzerothCore 3.3.5a — прогрессия, боты, аукцион

Личный сервер WoW **3.3.5a (12340)** на **Ubuntu 22.04/24.04 LTS**.  
Клиент — на **Bazzite** (не Windows).

Этот репозиторий — только **нативная** установка (clang + MySQL + systemd).  
Docker для AzerothCore **не используется** (на ВМ Docker может стоять для *arr — его не трогаем).

Клонируйте на ВМ, например в `~/azerothcore-deploy`.

---

## Что получите

| Вариант | Для кого | ИИ-боты |
|---------|----------|---------|
| **lonewolf** | 1–3 живых игрока | нет |
| **npcbots** | вы + до 4 нанятых спутников | да (NPCBots) |
| **playerbots** | ~200 ботов в `/who`, рейд по инвайту | да (отдельный форк) |

У всех: **Individual Progression**, все профессии на одном чаре, **AHBot**, **AutoBalance**, русский клиент.

На портах **3724 / 8085** крутится **только один** вариант. Остальные можно держать установленными и переключать.

### Важно про «поверх»

Каждый вариант — **своя сборка ядра** (разные git-форки) и **своя БД мира/персонажей**.  
Общее на ВМ:

- карты `~/azerothcore-data`
- пароль MySQL `~/azerothcore-servers/mysql-password`
- IP реалма в `~/azerothcore-servers/shared/`
- аккаунты (логины) — копируются при `install.sh` / `switch.sh`, если у обоих уже был первый запуск

Персонажи **не** переезжают между lonewolf ↔ playerbots ↔ npcbots (несовместимые схемы).

---

## Железо

| Вариант | RAM на ВМ |
|---------|-----------|
| lonewolf / npcbots | от **8 ГБ** |
| playerbots (~200 ботов) | от **16 ГБ** (с *arr теснее — уменьшите число ботов в конфиге) |

Диск: десятки ГБ (исходники + сборка + maps).  
GPU нужен только для опции чата Ollama у playerbots.

---

## Пошаговая установка (голая Ubuntu + Docker для *arr)

Ниже — полный путь с нуля. Подставьте свой логин вместо `romanov`, если нужно.

### Шаг 0. SSH на ВМ

```bash
ssh romanov@IP_ВМ
```

Нужен пользователь с `sudo` (пароль спросит при установке пакетов).

### Шаг 1. Минимальные пакеты и клон

```bash
sudo apt update
sudo apt install -y git curl ca-certificates
```

```bash
git clone -b azerothcore-progressive --single-branch \
  https://github.com/golovizninni-ai/cursor_stuff.git ~/azerothcore-deploy
cd ~/azerothcore-deploy
git pull
```

*(Docker / *arr не трогайте — AzerothCore ставится мимо compose.)*

### Шаг 2. Выберите вариант и поставьте

Рекомендуемый первый заход — **lonewolf** (быстрее и легче).

```bash
cd ~/azerothcore-deploy
./scripts/install.sh lonewolf
```

Долго: пакеты, MySQL, клон ядра, cmake/clang, конфиги, systemd-юниты.  
В конце скрипт сам запишет `active-variant=lonewolf`.

Каталоги после успеха:

| Путь | Назначение |
|------|------------|
| `~/azerothcore-servers/lonewolf/src/` | исходники |
| `~/azerothcore-servers/lonewolf/dist/bin/` | `authserver`, `worldserver` |
| `~/azerothcore-servers/mysql-password` | пароль пользователя `acore` |
| `~/azerothcore-servers/active-variant` | какой стек поднимет `start.sh` без аргументов |
| `~/azerothcore-data/` | карты (пока пусто — шаг 3) |

### Шаг 3. Клиентские data (один раз на ВМ)

Серверу нужны папки **dbc, maps, vmaps, mmaps** (лучше ещё `cameras`) в `~/azerothcore-data`.  
Язык **dbc = enUS** (даже если играете на русском клиенте).

Самый простой путь — готовый архив:

1. Скачайте client-data enUS с релизов [wowgaming/client-data](https://github.com/wowgaming/client-data/releases) (или зеркало AzerothCore).
2. Залейте на ВМ и распакуйте:

```bash
# пример: архив уже лежит в /tmp/ac-data.zip
./scripts/import-data.sh /tmp/ac-data.zip
ls ~/azerothcore-data   # должны быть maps, dbc, vmaps, mmaps
```

Альтернатива — экстракт с вашего клиента на Bazzite: [desktop/README.md](desktop/README.md).

**Без этого шага worldserver не поднимется нормально.**

### Шаг 4. Первый запуск в tmux (импорт SQL + ГМ-аккаунт)

Systemd ещё не используйте: первый старт создаёт таблицы и может идти долго.

```bash
tmux new -s ac-lonewolf
```

Внутри сессии:

```bash
~/azerothcore-servers/lonewolf/dist/bin/authserver &
~/azerothcore-servers/lonewolf/dist/bin/worldserver
```

Ждите в логе что-то вроде `World initialized` / `AzerothCore`.  
В **консоли worldserver** (курсор в том же окне), **без точки** в начале:

```
account create МойЛогин МойПароль
account set gmlevel МойЛогин 3 -1
```

Остановить worldserver: `Ctrl+C`.  
Отцепить tmux, не убивая auth: `Ctrl+B`, затем `D`.  
Потом можно убить оставшийся auth:

```bash
pkill -x authserver || true
```

### Шаг 5. IP реалма

Узнайте IP ВМ в LAN (или белый / Tailscale):

```bash
hostname -I | awk '{print $1}'
```

```bash
./scripts/set-realm-address.sh lonewolf 192.168.x.x
```

Иначе клиент после логина пойдёт на `127.0.0.1`.

### Шаг 6. Обычный день

```bash
cd ~/azerothcore-deploy
./scripts/start.sh lonewolf    # или просто ./scripts/start.sh — возьмёт active-variant
./scripts/status.sh
./scripts/stop.sh              # сначала world (сейв), потом auth — не kill -9
```

Логи:

```bash
journalctl --user -u ac-lonewolf-world.service -f
```

Автозапуск после перезагрузки ВМ (когда всё стабильно):

```bash
./scripts/enable-autostart.sh lonewolf
```

### Шаг 7. Клиент на Bazzite

1. WoW **3.3.5a build 12340**, язык **ruRU** (Lutris / Bottles / Proton).
2. В префиксе игры файл `Data/ruRU/realmlist.wtf`:

```
set realmlist 192.168.x.x
```

(тот же IP, что в `set-realm-address.sh`)

3. Логин/пароль — те, что создали в шаге 4.  
4. Аддоны: [docs/addons.md](docs/addons.md). Геймпад: [docs/consoleport.md](docs/consoleport.md).

Друзьям пробросьте **TCP 3724 и 8085**. MySQL (3306) наружу не открывать. [docs/ports.md](docs/ports.md).

### Шаг 8. В игре

- ГМ: `.gm on`, `.teleport Stormwind`, `.ip set 6` — [docs/gm-commands.md](docs/gm-commands.md)
- Профессии: на сервере уже `MaxPrimaryTradeSkill = 11`
- AHBot: создайте персонажа-заглушку, зайдите один раз, выйдите, затем  
  `./scripts/setup-ahbot.sh lonewolf <account_id> <char_guid>` и `./scripts/restart.sh lonewolf`

---

## Второй вариант поверх (playerbots / npcbots)

Lonewolf уже работает — хотите ботов:

```bash
cd ~/azerothcore-deploy
./scripts/install.sh playerbots
```

Что произойдёт:

1. Lonewolf остановится (порты освободятся).
2. Соберётся **отдельное** дерево `~/azerothcore-servers/playerbots/`.
3. Создадутся БД `ac_pb_*` (мир lonewolf `ac_lw_*` **останется**).
4. `active-variant` станет `playerbots`.
5. Карты те же (`~/azerothcore-data`).
6. Если у lonewolf уже был первый запуск — скрипт попробует скопировать **аккаунты** и IP реалма.

Потом снова **первый запуск playerbots в tmux** (свои пустые world/characters), затем:

```bash
./scripts/set-realm-address.sh playerbots 192.168.x.x
./scripts/start.sh playerbots
```

Вернуться на lonewolf без пересборки:

```bash
./scripts/switch.sh lonewolf
```

`switch.sh` синхронизирует аккаунты/IP и поднимает выбранный стек.  
Персонажи у каждого варианта свои.

Проверка:

```bash
./scripts/status.sh
./scripts/doctor.sh playerbots
cat ~/azerothcore-servers/active-variant
```

Почему раньше `start.sh` поднимал lonewolf после неудачного playerbots:  
`active-variant` пишется только после успешного install/start. Неполный playerbots его не менял. Теперь `install.sh` пишет active сразу, а `start.sh` без аргумента проверяет, что вариант реально установлен.

---

## Снос и чистая переустановка

```bash
./scripts/uninstall.sh -y lonewolf          # один вариант
./scripts/uninstall.sh -y all --purge-data  # всё + карты
./scripts/install.sh lonewolf
```

Снимает systemd, процессы, каталоги, MySQL `ac_*_*`, остатки старых docker-контейнеров `ac-*` (не *arr).

---

## Опции

### Чат ботов (Ollama) — только playerbots + GPU

```bash
./scripts/enable-ollama-chat.sh playerbots
```

1660 Ti → `qwen2.5:3b`. После 3070 Ti:  
`OLLAMA_MODEL=qwen2.5:7b ./scripts/enable-ollama-chat.sh playerbots`  
[docs/ollama-chat.md](docs/ollama-chat.md).

### HD-модели на клиенте

Патчи ChromieCraft только на Bazzite. Realmlist после патча — **ваш IP**. [docs/visuals.md](docs/visuals.md).

---

## Русификация

Русский клиент. На сервере: `RealmZone = 12`, `SupportedLocales = 0,8`, **DBC enUS**.  
Часть квестов в БД на английском. Команды playerbots — английские.

---

## Карта скриптов

| Скрипт | Назначение |
|--------|------------|
| `install.sh` | Полная нативная установка / доустановка варианта |
| `switch.sh` | Переключить уже установленный вариант |
| `start.sh` `stop.sh` `status.sh` `restart.sh` | День за днём |
| `set-realm-address.sh` | IP в realmlist + shared |
| `setup-ahbot.sh` | Включить продавца/покупателя АН |
| `import-data.sh` | Распаковать maps/dbc в `~/azerothcore-data` |
| `doctor.sh` | Диагностика |
| `uninstall.sh` | Полный снос |
| `enable-autostart.sh` | Автозапуск systemd |
| `enable-ollama-chat.sh` | Опция чата (playerbots) |

Не `kill -9` на worldserver — сначала `stop.sh` (сейв персонажей).
