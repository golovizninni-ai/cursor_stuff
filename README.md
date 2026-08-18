# AzerothCore 3.3.5a: прогрессия, боты, аукцион

Набор скриптов для **Ubuntu 22.04/24.04 LTS**. Debian-ВМ не нужна.

Три варианта на разных ядрах (одновременно на портах 3724/8085 крутится только один):

| Вариант | Команда | Для кого |
|---------|---------|----------|
| **playerbots** | `scripts/install.sh playerbots` | Живой мир: ~200 ботов в `/who`, рейд по инвайту. AutoBalance сжимает инст, если полный состав не собрали. |
| **npcbots** | `scripts/install.sh npcbots` | Вы + до 4 нанятых спутников. AutoBalance (форк trickerer) считает их игроками — рейды проходимы впятером. |
| **lonewolf** | `scripts/install.sh lonewolf` | Без ИИ-ботов. 1–3 живых игрока, инсты режет AutoBalance. Локально или друзья по проброшенным портам. |

Общее во всех трёх: [Individual Progression](https://github.com/ZhengPeiRu21/mod-individual-progression) (мир открывается **вашими** киллами), все профессии на одном персонаже, [AHBot](https://github.com/azerothcore/mod-ah-bot) (расходники + выкуп ваших лотов), русский **клиент**.

ChromieCraft не используется: там фазы открывает админ по календарю, не ваш персонаж.

## Железо

- playerbots, 200 ботов: от **16 ГБ RAM**, 4 ядра, сильный single-core, ~50 ГБ диска.
- npcbots / lonewolf: обычно хватает **8 ГБ**.

Клиент и MPQ этот репозиторий не содержит. Нужен ваш WoW **3.3.5a (12340)**.

## Русификация

Хватает **русского клиента**. Интерфейс, спеллы, таланты, карта — из `Data/ruRU`.

На сервере специально:

- `RealmZone = 12` — кириллица в именах;
- `SupportedLocales = 0,8` — чтобы ru-клиент не ронял чат;
- **DBC на сервере enUS** — иначе ломается ИИ playerbots.

Квестовые тексты из базы AC по-русски неполные: часть будет по-английски. Команды ботов (`follow`, `grind`) тоже английские.

## Установка на ВМ

```bash
sudo apt-get update && sudo apt-get install -y git
git clone <URL_ЭТОГО_РЕПО> ~/azerothcore-deploy
cd ~/azerothcore-deploy
chmod +x scripts/*.sh
# один вариант:
./scripts/install.sh playerbots
# или npcbots / lonewolf
```

Скрипт ставит пакеты, MySQL, клонирует нужный форк, собирает clang’ом, пишет конфиги и systemd-юниты.

Каталоги:

- исходники и бинарники: `~/azerothcore-servers/<вариант>/`
- пароль БД: `~/azerothcore-servers/mysql-password`
- карты: `~/azerothcore-data/`

### Data-файлы (десктоп — Bazzite / Fedora)

Сервер без `dbc/maps/vmaps/mmaps` не стартует. Клиент живёт на **Bazzite**, не на Windows. Инструкция: [desktop/README.md](desktop/README.md).

Кратко: либо скачать enUS client-data и `scripts/import-data.sh архив.zip`, либо `desktop/push-client-to-vm.sh` и на ВМ `scripts/extract-from-client.sh`.

### Запуск и остановка

Подробно: [docs/service.md](docs/service.md).

```bash
./scripts/start.sh playerbots    # npcbots / lonewolf
./scripts/status.sh
./scripts/stop.sh                # сначала world (сейв), потом auth
./scripts/restart.sh
```

Первый раз (импорт SQL, `account create`) — в tmux, не через systemd. Не используйте `kill -9` на worldserver.

Оставить ВМ работать сутками:

```bash
./scripts/enable-autostart.sh playerbots
./scripts/start.sh playerbots
```

Снять с автозагрузки: `./scripts/disable-autostart.sh` (процесс сам не убивает — для этого `stop.sh`).

### Первый запуск (консоль)

Не через systemd (нужна консоль):

```bash
tmux new -s ac
~/azerothcore-servers/playerbots/dist/bin/authserver   # другое окно tmux
~/azerothcore-servers/playerbots/dist/bin/worldserver
```

Дождитесь импорта SQL. Затем в консоли worldserver:

```
account create ИМЯ ПАРОЛЬ
account set gmlevel ИМЯ 3 -1
```

Создайте в игре обычного персонажа **AuctioneerBot** (им не играют). Узнайте id аккаунта и guid персонажа в БД и:

```bash
./scripts/setup-ahbot.sh playerbots <account_id> <guid>
./scripts/set-realm-address.sh playerbots <IP_ВМ>
```

Дальше можно `./scripts/start.sh playerbots`. Насовсем: `./scripts/enable-autostart.sh playerbots`.

### Профессии

`MaxPrimaryTradeSkill = 11`. Клиент рисует две кнопки — остальные макросом `/cast Enchanting` и т.д.

### Боты

**Playerbots:** инвайт из `/who`, `.playerbots bot addclass warrior`, `.playerbots bot init=rare Имя`, в пати `/p follow`. Аддоны: [docs/addons.md](docs/addons.md).

**NPCBots:** нанять у спавна в городе или `.npcbot`. В рейд их пускает конфиг; сложность жмёт AutoBalance.

**Lonewolf:** ботов нет. Сложность инста = число живых игроков (от одного).

Если playerbots + AutoBalance падает worldserver на входе в BG — в `AutoBalance.conf` поставьте `AutoBalance.Enable.Global = 0` и перезапустите мир.

## Клиент

`Data/ruRU/realmlist.wtf`:

```
set realmlist IP_ВМ
```

Аддоны: [docs/addons.md](docs/addons.md).  
Геймпад / ConsolePortLK: [docs/consoleport.md](docs/consoleport.md).

## Проброс портов для друзей

Нужны только два TCP-порта на ВМ:

- **3724** — логин (authserver)
- **8085** — мир (worldserver)

Перед тем как звать друзей: `./scripts/start.sh <вариант>` (или автозапуск, [docs/service.md](docs/service.md)).

MySQL (3306) наружу не открывать. После проброса тот же IP пропишите в реалме: `scripts/set-realm-address.sh <вариант> <внешний_IP>`.

Подробности, LAN vs CGNAT, Tailscale: [docs/ports.md](docs/ports.md).
