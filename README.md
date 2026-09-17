# cursor_stuff

Черновики и эксперименты Cursor. Каждый проект живёт в своей долгоживущей ветке — в `main` только это оглавление.

## Проекты

| Ветка | Описание |
|-------|----------|
| [`azerothcore-progressive`](https://github.com/golovizninni-ai/cursor_stuff/tree/azerothcore-progressive) | AzerothCore 3.3.5a (playerbots / npcbots / lonewolf): **только native**, Individual Progression, AHBot, AutoBalance, опции Ollama и HD-клиента |
| [`homelab-local-ai`](https://github.com/golovizninni-ai/cursor_stuff/tree/homelab-local-ai) | Локальный AI-хаб (Docker): Open WebUI, Ollama, SearXNG, ComfyUI, Aider; воркеры 3060 Ti / 9070 XT в LAN |
| [`tdarr-hevc`](https://github.com/golovizninni-ai/cursor_stuff/tree/tdarr-hevc) | Tdarr HEVC + mux озвучек: hardlink-скрипт `flatten.py`, Compose, NVENC (GTX 1660 Ti) |
| [`arr-stack`](https://github.com/golovizninni-ai/cursor_stuff/tree/arr-stack) | ARR-стек в Docker: Prowlarr / Sonarr / Radarr / Lidarr / Readarr / Bazarr + qBittorrent |
| [`save-sync`](https://github.com/golovizninni-ai/cursor_stuff/tree/save-sync) | Syncthing-хаб сохранений эмуляторов (Proxmox + NFS); клиенты Bazzite, Steam Deck, Mangmi, muOS |

## Клон одной ветки

```bash
git clone -b <ветка> --single-branch \
  https://github.com/golovizninni-ai/cursor_stuff.git ~/<папка>
cd ~/<папка>
```

Примеры:

```bash
git clone -b azerothcore-progressive --single-branch \
  https://github.com/golovizninni-ai/cursor_stuff.git ~/azerothcore-deploy

git clone -b homelab-local-ai --single-branch \
  https://github.com/golovizninni-ai/cursor_stuff.git ~/local-ai

git clone -b tdarr-hevc --single-branch \
  https://github.com/golovizninni-ai/cursor_stuff.git ~/tdarr-hevc

git clone -b arr-stack --single-branch \
  https://github.com/golovizninni-ai/cursor_stuff.git ~/arr-stack

git clone -b save-sync --single-branch \
  https://github.com/golovizninni-ai/cursor_stuff.git ~/save-sync
```
