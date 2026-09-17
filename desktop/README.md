# Десктоп: Bazzite (Fedora Atomic)

Клиент на **Bazzite**, сервер на Ubuntu-ВМ. Windows не нужен.

Нужно:

1. **Играть:** WoW **3.3.5a build 12340**, язык **ruRU** (Lutris / Bottles / Proton).
2. **Серверу:** папки `dbc`, `maps`, `vmaps`, `mmaps` (и по возможности `cameras`) в `~/azerothcore-data` на ВМ.

Серверные `dbc` — **enUS**. Карты от языка клиента не зависят.  
Bazzite неизменяемый: **не** ставьте gcc/cmake через `rpm-ostree` ради экстракторов.

## Быстрый путь (рекомендуется)

Архив enUS: [wowgaming/client-data](https://github.com/wowgaming/client-data/releases)

```bash
scp ac-data.zip USER@VM:/tmp/
ssh USER@VM 'bash ~/azerothcore-deploy/scripts/import-data.sh /tmp/ac-data.zip'
```

Русский клиент на Bazzite всё равно нужен, чтобы зайти в игру.

## Извлечение из вашего клиента

1. На ВМ соберите любой вариант (`install.sh`) — появятся экстракторы в `~/azerothcore-servers/<вариант>/dist/bin/`.
2. На Bazzite найдите корень клиента (`Wow.exe` рядом с `Data/`):

```bash
chmod +x desktop/*.sh
desktop/find-wow-client.sh
```

3. Залейте клиент на ВМ (`rsync`):

```bash
desktop/push-client-to-vm.sh \
  --wow-dir "/path/to/WoW335" \
  --server USER@IP_ВМ \
  --remote-dir /home/USER/wow-client
```

4. На ВМ:

```bash
scripts/extract-from-client.sh /home/USER/wow-client lonewolf
```

Если клиент ruRU — после экстракта подмените `~/azerothcore-data/dbc` английским архивом client-data.

## Realmlist

В **префиксе** игры:

`drive_c/.../Data/ruRU/realmlist.wtf`

```
set realmlist IP_ВАШЕЙ_ВМ
```

Аддоны: [docs/addons.md](../docs/addons.md). Геймпад: [docs/consoleport.md](../docs/consoleport.md).  
HD-патчи (клиент): [docs/visuals.md](../docs/visuals.md).
