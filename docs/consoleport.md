# ConsolePort на Bazzite (3.3.5a)

В 3.3.5 нет нативного геймпада. На Bazzite клиент почти всегда в **Proton/Wine**, поэтому связка такая:

1. Аддон **[ConsolePortLK](https://github.com/leoaviana/ConsolePortLK/releases/latest)** — в `Interface/AddOns/` **внутри того же префикса**, что и `Wow.exe`.
2. Маппер **[WoWpadX](https://github.com/leoaviana/WoWpadX)** — тоже Windows-exe, его запускают **тем же Proton**, что и игру.

Это порт ConsolePort 1.9.17 под WotLK, не аддон ConsolePort с CurseForge (Retail/Classic).

## Установка аддона

1. Скачайте zip ConsolePortLK, распакуйте **все** папки (`ConsolePort`, `ConsolePortBar`, …) в  
   `.../pfx/drive_c/.../Interface/AddOns/`.
2. Не ставьте Bartender4 / Dominos вместе с ConsolePort — конфликт панелей.

В игре:

```
/cp config
/cp type
/cp help
/cp recalibrate
/cp actionbar
```

Выключили аддон → `/reload` → снова клавиатура и мышь.

## WoWpadX + Steam на Bazzite

Оба exe добавьте в Steam как non-Steam, **одинаковая версия Proton**.

1. Сначала запустите WoWpadX, подключите геймпад, затем Wow.
2. Launch Options WoWpadX (Properties → General):

```
-l "Z:\path\inside\prefix\to\Wow.exe"
```

Либо Linux-путь, если Proton его проглатывает: `-l "/var/home/USER/Games/WoW/Wow.exe"`.

3. Если WoWpadX не видит процесс игры — у `Wow.exe` в Launch Options:

```
PROTON_REMOTE_DEBUG_CMD="/var/home/USER/Games/WoWpadX/WoWpadX.exe" %command%
```

Оба должны жить в одном compatdata/prefix. На Bazzite удобно Lutris «Wine prefix» и туда же прописать exe маппера.

4. Steam Input: имя игры `World of Warcraft: WotLK`, раскладка Community `Gamepad leoaviana ConsolePortLK` (Show All Layouts). На Bazzite Steam Input включён по умолчанию, как на Deck.

5. В настройках контроллера Steam для этой игры отключите «Desktop Layout», иначе правый стик уйдёт в системный курсор, а не в WoWpadX.

## Игра без Steam (Lutris / Bottles)

- Геймпад: в Lutris включите SDL, либо запускайте WoWpadX тем же runner/wine, что и Wow (`wine WowpadX.exe`, затем `wine Wow.exe` в том же prefix).
- Не смешивайте system Steam Input и Lutris anti-micro, если уже крутится WoWpadX.

## Под наши варианты

- **Lonewolf / NPCBots:** геймпад нормален для квестов и пятёрки.
- **Playerbots:** инвайт и `.playerbots` удобнее с клавиатуры; геймпад — открытый мир.
- Чат и GM-команды с геймпада мучительны — клавиатура рядом.

## Если не биндится

- Клиент 3.3.5a **12340**, не Classic.
- Аддон включён уже на экране персонажей.
- После обновления ConsolePortLK: `/cp resetall` или чистый `WTF/` в префиксе.
- Кастомные «репаки» клиента с ломаным RestrictedEnvironment аддон не переваривает.
