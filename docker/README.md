# Docker (вариант B)

Отдельный compose-проект рядом с *arr, не в одном файле. Гайд: [docs/install-docker.md](../docs/install-docker.md).

```bash
./scripts/install-docker.sh playerbots   # npcbots / lonewolf
```

Не вызывайте отсюда `scripts/install.sh` — это нативная сборка (clang + хостовый MySQL).

Файлы:

- `compose.override.yml` — шаблон; install-docker дописывает `container_name` и env ботов
- `env.example` — порты и пароль БД

На хост: 3724 и 8085. 3306/7878 не занимаем (MariaDB/Radarr).
