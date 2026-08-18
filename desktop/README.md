# Десктоп: Bazzite (Fedora Atomic)

Клиент крутится на **Bazzite**, сервер — на Ubuntu-ВМ. Windows не нужен.

Нужно два комплекта:

1. **Играть:** WoW **3.3.5a build 12340**, язык **ruRU** (Lutris, Bottles или non-Steam Proton).
2. **Сервер:** папки `dbc`, `maps`, `vmaps`, `mmaps` (и по возможности `cameras`).

Серверные `dbc` — **enUS** (playerbots ищут спеллы по английским именам). Карты от языка не зависят.

Bazzite неизменяемый: **не** ставьте gcc/cmake через `rpm-ostree` ради экстракторов.

Если сервер ставите **Docker** (`install-docker.sh`), карты качает контейнер `ac-client-data` (enUS). Этот раздел нужен только для **нативной** установки.

## Быстрый путь

Архив enUS с релизов AzerothCore / [wowgaming/client-data](https://github.com/wowgaming/client-data/releases):

```bash
scp ac-data.zip USER@VM:/tmp/
ssh USER@VM 'bash ~/azerothcore-deploy/scripts/import-data.sh /tmp/ac-data.zip'
```

Русский клиент на Bazzite всё равно нужен, чтобы зайти в игру.

## Извлечение из вашего клиента

1. На ВМ соберите любой стек — появятся экстракторы в `~/azerothcore-servers/<вариант>/dist/bin/`.
2. На Bazzite найдите корень клиента (`Wow.exe` рядом с `Data/`):

```bash
chmod +x desktop/*.sh
desktop/find-wow-client.sh
```

Типичные места:

- Lutris: каталог, который указали при установке
- Steam Proton: `~/.steam/steam/steamapps/compatdata/<ID>/pfx/drive_c/Program Files/...`
- Bottles: `~/.local/share/bottles/bottles/<имя>/drive_c/...`

3. Залейте клиент на ВМ (50+ ГБ, нужен `rsync`; на Bazzite он уже есть):

```bash
desktop/push-client-to-vm.sh \
  --wow-dir "/path/to/WoW335" \
  --server USER@IP_ВМ \
  --remote-dir /home/USER/wow-client
```

4. На ВМ:

```bash
scripts/extract-from-client.sh /home/USER/wow-client playerbots
```

Если клиент ruRU — после экстракта подмените `~/azerothcore-data/dbc` английским архивом client-data.

## Realmlist

В **префиксе** игры, не в «нативном» Linux-пути Steam:

`drive_c/.../Data/ruRU/realmlist.wtf`

```
set realmlist IP_ВАШЕЙ_ВМ
```

Язык клиента — русский, иначе читается `Data/enUS/`.

Аддоны кладите в тот же префикс: `Interface/AddOns/`. Геймпад: [docs/consoleport.md](../docs/consoleport.md).
