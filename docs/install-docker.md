# Docker-установка (вариант B)

Для ВМ, где уже есть Docker (*arr). **Не** добавляйте сервисы в compose Sonarr/Radarr.

```bash
cd ~/azerothcore-deploy
./scripts/install-docker.sh playerbots    # npcbots / lonewolf
```

Нужны `docker` и `docker compose`. Clang и MySQL на хост **не** ставятся. Маркер: `~/azerothcore-servers/<вариант>/install-mode` = `docker`.

Проект compose: `ac-playerbots` / `ac-npcbots` / `ac-lonewolf`. Контейнеры с префиксом варианта, чтобы не пересечься.

## Порты и *arr

На хост только **3724** и **8085**. MySQL с хоста: `127.0.0.1:13306` (не 3306). SOAP: `127.0.0.1:17878` (не 7878 Radarr).

RAM: *arr + 200 playerbots. На 16 ГБ снизьте `AC_AI_PLAYERBOT_MAX_RANDOM_BOTS` в override.

## Data

Контейнер `ac-client-data-init` качает **enUS** maps/dbc. Клиент на Bazzite нужен только чтобы играть и прописать realmlist. Снимать карты с Bazzite для Docker не обязательно.

## Первый запуск и аккаунт

После `install-docker.sh` (долгая сборка образа):

```bash
./scripts/start.sh playerbots
docker attach ac-playerbots-worldserver
```

`account create ИМЯ ПАРОЛЬ` затем `account set gmlevel ИМЯ 3 -1`. Отцепиться: **Ctrl+P, Ctrl+Q** (не Ctrl+C).

```bash
./scripts/set-realm-address.sh playerbots <IP_ВМ>
./scripts/setup-ahbot.sh playerbots <account_id> <guid>
```

Логи: `docker compose -p ac-playerbots logs -f ac-worldserver` из каталога форка или `./scripts/status.sh`.

## Автозапуск

В override уже `restart: unless-stopped`. `docker.service` у *arr обычно включён. `./scripts/enable-autostart.sh` для Docker только проверяет это.

## NPCBots

Если в форке нет `docker-compose.yml`, скрипт остановится и предложит [install-native.md](install-native.md).

Playerbots в Docker официально «limited support»: при ошибке сборки используйте нативный путь.
