# Запуск, стоп и автозапуск

Один стек: `playerbots`, `npcbots` или `lonewolf`. Режим: `~/azerothcore-servers/<вариант>/install-mode` (`native` или `docker`). Не `kill -9` на worldserver.

## Обычный день (оба режима)

```bash
./scripts/start.sh lonewolf
./scripts/status.sh
./scripts/stop.sh
./scripts/restart.sh
```

Стоп **того же** варианта: сначала world, потом auth. В Docker БД этого варианта остаётся (быстрый следующий start).

Переключение на другой вариант: `start.sh` глушит чужой стек целиком, **включая database**, иначе порт **13306** занят и новый world падает в Restarting.

## Native

Логи: `journalctl --user -u ac-lonewolf-world -f` (подставьте вариант)

Первый импорт SQL — tmux, не systemd. Консоль: `account create`. Потом `start.sh`. Команды: [gm-commands.md](gm-commands.md).

Автозапуск: `./scripts/enable-autostart.sh lonewolf` (mysql + linger + юниты).

## Docker

Логи: `docker logs -f ac-lonewolf-worldserver`

Консоль: `docker attach ac-lonewolf-worldserver`. Отцепиться: **Ctrl+P Ctrl+Q**.

Если `status` показывает Restarting — [README §8](../README.md) и [install-docker.md](install-docker.md).

Автозапуск: `restart: unless-stopped` + `docker.service`.

## Порты

Друзьям: **3724** и **8085**. Ollama (опция) — 11434 только на ВМ. [ports.md](ports.md).
