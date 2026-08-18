# Запуск, стоп и автозапуск

Один стек: `playerbots`, `npcbots` или `lonewolf`. Режим смотрится в `~/azerothcore-servers/<вариант>/install-mode` (`native` или `docker`). Не `kill -9` на worldserver.

## Обычный день (оба режима)

```bash
./scripts/start.sh playerbots
./scripts/status.sh
./scripts/stop.sh
./scripts/restart.sh
```

Стоп: сначала world, потом auth.

## Native

Логи: `journalctl --user -u ac-playerbots-world -f`

Первый импорт SQL — tmux, не systemd. Консоль: `account create`. Потом `start.sh`.

Автозапуск: `./scripts/enable-autostart.sh playerbots` (mysql + linger + юниты).

## Docker

Логи: `./scripts/status.sh` подскажет `docker compose logs`.

Консоль: `docker attach ac-playerbots-worldserver`. Отцепиться: **Ctrl+P Ctrl+Q**.

`stop.sh` останавливает auth/world, контейнер БД остаётся.

Автозапуск: `restart: unless-stopped` + `docker.service` (как *arr). `enable-autostart.sh` выставляет unless-stopped.

## Порты

Друзьям: **3724** и **8085**. Подробности: [ports.md](ports.md).
