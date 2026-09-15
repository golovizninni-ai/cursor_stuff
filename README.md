# ARR stack (Docker Compose)

Prowlarr / Sonarr / Radarr / Lidarr / Readarr / Bazarr + qBittorrent.

Ветка: [`arr-stack`](https://github.com/golovizninni-ai/cursor_stuff/tree/arr-stack) (не мержить в `main`).

```bash
git clone -b arr-stack --single-branch \
  https://github.com/golovizninni-ai/cursor_stuff.git ~/arr-stack
cd ~/arr-stack
```

## Запуск

1. Создайте папки:
   ```bash
   mkdir -p data/{prowlarr,sonarr,radarr,lidarr,readarr,bazarr,qbittorrent}
   mkdir -p media/{tv,movies,music,books}
   mkdir -p downloads
   ```
2. Скопируйте `.env.example` в `.env`:
   ```bash
   cp .env.example .env
   ```
3. Запустите стек:
   ```bash
   docker compose up -d
   ```

## Веб-интерфейсы

| Сервис | Порт |
|--------|------|
| Prowlarr | 9696 |
| Sonarr | 8989 |
| Radarr | 7878 |
| Lidarr | 8686 |
| Readarr | 8787 |
| Bazarr | 6767 |
| qBittorrent | 8080 |

Дальше в UI: индексеры в Prowlarr, download client (qBittorrent) и пути в *arr.
