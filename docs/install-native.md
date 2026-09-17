# Нативная установка

Кратко: весь пошаговый путь — в [README.md](../README.md).

```bash
cd ~/azerothcore-deploy
./scripts/install.sh lonewolf    # или npcbots / playerbots
```

Пакеты, MySQL, клон форка, сборка, systemd.  
Карты: `scripts/import-data.sh` → `~/azerothcore-data`.  
Первый импорт SQL — tmux + ручной `worldserver`, не сразу systemd.

Второй вариант поверх: снова `install.sh <другой>`. Переключение без пересборки: `scripts/switch.sh <вариант>`.

Сервис день за днём: [service.md](service.md).
