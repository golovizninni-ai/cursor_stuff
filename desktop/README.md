# Десктоп (Buzzit): клиент и data-файлы

Сервер **не** качает игровой клиент. Извлечение карт делает Buzzit на Windows-ПК, затем архив кладётся на Ubuntu.

Нужно два комплекта:

1. **Играть:** клиент WoW **3.3.5a build 12340**, язык **ruRU**.
2. **Сервер:** папки `dbc`, `maps`, `vmaps`, `mmaps` (и по возможности `cameras`).

Серверные `dbc` должны быть **enUS** (playerbots ищут спеллы по английским именам). Карты (`maps`/`vmaps`/`mmaps`) от языка не зависят — их можно снять с русского клиента.

## Быстрый путь (рекомендуется Buzzit)

Официальный набор enUS для AzerothCore (актуальный релиз смотрите на вики AC, «Server Setup» → client data):

https://github.com/wowgaming/client-data/releases

Скачать архив, залить на ВМ, распаковать:

```bash
scp ac-data.zip USER@VM:/tmp/
ssh USER@VM 'bash ~/azerothcore-deploy/scripts/import-data.sh /tmp/ac-data.zip'
```

Путь `~/azerothcore-deploy` замените на каталог, куда клонирован **этот** репозиторий.

Русский клиент при этом всё равно нужен на ПК, чтобы зайти в игру.

## Извлечение из вашего клиента

1. Соберите любой вариант на ВМ (`scripts/install.sh playerbots` и т.д.) — появятся Linux-экстракторы в `~/azerothcore-servers/<вариант>/dist/bin/`.
2. Залейте каталог клиента на ВМ (50+ ГБ) скриптом `Extract-AzerothCoreData.ps1`.
3. На ВМ:

```bash
scripts/extract-from-client.sh /home/USER/wow-client playerbots
```

Если клиент ruRU, после экстракта подмените `~/azerothcore-data/dbc` английским архивом из client-data.

## Realmlist на клиенте

Файл `World of Warcraft/Data/ruRU/realmlist.wtf`:

```
set realmlist IP_ВАШЕЙ_ВМ
```

В лаунчере язык должен быть русский, иначе читается `Data/enUS/`.
