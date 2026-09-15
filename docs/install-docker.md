# Docker-установка (вариант B)

Для ВМ, где уже есть Docker (*arr). **Не** добавляйте сервисы в compose Sonarr/Radarr.

```bash
cd ~/azerothcore-deploy   # или куда склонировали этот репозиторий
./scripts/install-docker.sh lonewolf    # playerbots / npcbots / lonewolf
```

Нужны `docker` и `docker compose`. Clang и MySQL на хост **не** ставятся. Маркер: `~/azerothcore-servers/<вариант>/install-mode` = `docker`.

Проект compose: `ac-playerbots` / `ac-npcbots` / `ac-lonewolf`. Контейнеры с префиксом варианта.

## Порты и *arr

На хост только **3724** и **8085**. MySQL с хоста: `127.0.0.1:13306` (не 3306). SOAP: `127.0.0.1:17878` (не 7878 Radarr).

Одновременно один вариант: `start.sh` останавливает **world+auth+database** других стеков, иначе порт **13306** остаётся занят и новый world уходит в Restarting.

RAM: *arr + 200 playerbots — тесно на 16 ГБ (снизьте ботов). lonewolf/npcbots: `mem_limit` 4g.

## Data

Контейнер `ac-client-data-init` качает **enUS** maps/dbc. Клиент на Bazzite нужен только чтобы играть и прописать realmlist.

## Первый запуск и аккаунт

`install-docker.sh` сам: build → up → ждёт healthy → применяет overlays → рестарт world.

```bash
./scripts/start.sh lonewolf
docker attach ac-lonewolf-worldserver
```

`account create ИМЯ ПАРОЛЬ` затем `account set gmlevel ИМЯ 3 -1`. Отцепиться: **Ctrl+P, Ctrl+Q** (не Ctrl+C). Команды: [gm-commands.md](gm-commands.md).

```bash
./scripts/set-realm-address.sh lonewolf <IP_ВМ>
# AHBot (все варианты, после создания персонажа-заглушки):
./scripts/setup-ahbot.sh lonewolf <account_id> <guid>
```

Логи: `docker logs -f ac-lonewolf-worldserver` или `./scripts/status.sh`.

## Почему world падал (исправлено)

Раньше в override стояло `AC_UPDATES_ENABLE_DATABASES=7` на **world**. В официальном Docker миграции делает только `ac-db-import`, у world в образе `0`. Повторный SQL на старте → контейнер в **Restarting**, `start.sh` «не поднимает».

Сейчас: Updates на world принудительно **0** через [docker-apply-overlays.sh](../scripts/docker-apply-overlays.sh). Если у вас уже стоит старый стек:

```bash
./scripts/start.sh lonewolf
# или вручную:
# в env/dist/etc/worldserver.conf → Updates.EnableDatabases = 0
# docker restart ac-lonewolf-worldserver
docker logs --tail 200 ac-lonewolf-worldserver
```

## Автозапуск

В override уже `restart: unless-stopped`. `docker.service` у *arr обычно включён. `./scripts/enable-autostart.sh`.

## NPCBots

Если в форке нет `docker-compose.yml`, скрипт остановится и предложит [install-native.md](install-native.md).

Playerbots в Docker официально «limited support»: при ошибке сборки — нативный путь.

Опция чата ботов (Ollama на хосте с GPU): `scripts/enable-ollama-chat.sh playerbots` — [ollama-chat.md](ollama-chat.md).

## Опция: красивее модели и текстуры

Контейнеры не трогать. На клиенте Bazzite — HD ChromieCraft: [visuals.md](visuals.md).
