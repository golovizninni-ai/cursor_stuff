# Запуск, стоп и автозапуск

Один стек на ВМ: `playerbots`, `npcbots` или `lonewolf`. Не глушите `worldserver` через `kill -9` — персонажи и инсты не успеют записаться в MySQL.

## Обычный день

Из каталога репозитория на Ubuntu-ВМ:

```bash
./scripts/start.sh playerbots    # или npcbots / lonewolf
./scripts/status.sh
./scripts/stop.sh                # останавливает последний запущенный стек
./scripts/restart.sh
```

`start.sh` сам глушит другой вариант, если он был поднят через systemd. Первый аргумент можно не писать, если стек уже запускали — он запоминается в `~/azerothcore-servers/active-variant`.

Порядок стопа: **сначала world, потом auth**, ожидание до 90 секунд.

Логи:

```bash
journalctl --user -u ac-playerbots-world -f
# если ставили от root:
# journalctl -u ac-playerbots-world -f
```

## Первый запуск (консоль)

Пока worldserver импортирует SQL и вы создаёте аккаунт, удобнее tmux, не systemd:

```bash
./scripts/stop.sh playerbots   # если уже пробовали start
tmux new -s ac
~/azerothcore-servers/playerbots/dist/bin/authserver
# Ctrl+B C — новое окно
~/azerothcore-servers/playerbots/dist/bin/worldserver
```

В консоли мира: `account create ИМЯ ПАРОЛЬ` и `account set gmlevel ИМЯ 3 -1`. Выход: в консоли `server shutdown 1` либо просто закрыть tmux после `server shutdown`. Потом уже `./scripts/start.sh playerbots`.

## Оставить сервер надолго

После того как стек один раз нормально стартовал:

```bash
./scripts/enable-autostart.sh playerbots
./scripts/start.sh playerbots
```

Это:

- включает `mysql` в автозагрузку ВМ;
- включает `ac-<вариант>-auth` и `ac-<вариант>-world`;
- для user-systemd включает `loginctl linger`, чтобы после закрытия SSH сервер не умер.

Снять с автозагрузки (сам процесс не убивает):

```bash
./scripts/disable-autostart.sh
./scripts/stop.sh
```

Перезагрузка Ubuntu-ВМ при включённом автозапуске поднимет выбранный стек сама. Друзьям по-прежнему нужны порты **3724** и **8085**.
