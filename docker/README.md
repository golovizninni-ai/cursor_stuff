# Docker (вариант B)

Отдельный compose-проект рядом с *arr, не в одном файле. Гайд: [docs/install-docker.md](../docs/install-docker.md). Пошагово с разбором Restarting: [README.md](../README.md).

```bash
./scripts/install-docker.sh lonewolf   # playerbots / npcbots
```

Не вызывайте отсюда `scripts/install.sh` — это нативная сборка (clang + хостовый MySQL).

Файлы:

- `compose.override.yml` — **шаблон/справка**; реальный override пишет `install-docker.sh`
- `compose.ollama.yml` — опция чата (playerbots + GPU)
- `env.example` — порты и пароль БД

На хост: 3724 и 8085. 3306/7878 не занимаем (MariaDB/Radarr).  
**Не** ставьте `AC_UPDATES_ENABLE_DATABASES=7` на world — миграции только в `ac-db-import`.

Опция на клиенте (модели/текстуры ChromieCraft): [docs/visuals.md](../docs/visuals.md).  
Опция чата ботов: Ollama на **хосте** ВМ с GPU — [docs/ollama-chat.md](../docs/ollama-chat.md).
