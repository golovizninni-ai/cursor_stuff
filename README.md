# cursor_stuff

## ARR (Prowlarr/Sonarr/Radarr/Lidarr/Readarr/Bazarr + qBittorrent) через Docker Compose

1. Создайте папки (если хотите — вручную):
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

Дальше откройте веб-интерфейсы контейнеров и настройте:
- Prowlarr → индексеры
- Sonarr/Radarr/Lidarr/Readarr → индексеры, download client (qBittorrent), и пути (TV/MOVIES/...)
