# Запуск, стоп, переключение

Один активный стек на портах **3724/8085**: `playerbots`, `npcbots` или `lonewolf`.  
Не `kill -9` на worldserver — сначала `stop.sh` (сейв).

## Обычный день

```bash
./scripts/start.sh lonewolf
./scripts/status.sh
./scripts/stop.sh
./scripts/restart.sh
```

Без аргумента `start.sh` берёт `~/azerothcore-servers/active-variant` и проверяет, что вариант реально установлен.

## Переключение

```bash
./scripts/switch.sh playerbots   # уже установленный
./scripts/install.sh npcbots     # поставить новый поверх
```

`switch.sh` копирует аккаунты/IP реалма, если оба варианта уже поднимались.  
Мир и персонажи у каждого варианта свои.

## Логи

```bash
journalctl --user -u ac-lonewolf-world.service -f
```

Первый импорт SQL — tmux, не systemd. Консоль: `account create`. Команды: [gm-commands.md](gm-commands.md).

Автозапуск: `./scripts/enable-autostart.sh lonewolf` (mysql + linger + юниты).

## Снос

```bash
./scripts/uninstall.sh -y lonewolf
./scripts/uninstall.sh -y all --purge-data
```

## Порты

Друзьям: **3724** и **8085**. Ollama — только localhost. [ports.md](ports.md).
