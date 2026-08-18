# Нативная установка (вариант A)

Хостовый clang + MySQL + systemd. Не нужен Docker. Если на ВМ уже крутится *arr в Docker и не хотите второй тяжёлый build — смотрите [install-docker.md](install-docker.md).

```bash
cd ~/azerothcore-deploy
./scripts/install.sh playerbots    # npcbots / lonewolf
```

Скрипт: пакеты, MySQL 8, клон форка, сборка, конфиги, юниты. Маркер: `~/azerothcore-servers/<вариант>/install-mode` = `native`.

Каталоги:

- `~/azerothcore-servers/<вариант>/`
- пароль БД: `~/azerothcore-servers/mysql-password`
- карты: `~/azerothcore-data/` — [desktop/README.md](../desktop/README.md)

Первый импорт SQL — tmux, затем:

```bash
./scripts/start.sh playerbots
./scripts/stop.sh
./scripts/enable-autostart.sh playerbots
```

Подробнее: [service.md](service.md). Аккаунт: `account create` в консоли worldserver. AHBot: `setup-ahbot.sh`. Адрес реалма: `set-realm-address.sh`.
