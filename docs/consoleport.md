# ConsolePort для 3.3.5a

В 3.3.5 нет нативного геймпада. Нужны два компонента:

1. Аддон **[ConsolePortLK](https://github.com/leoaviana/ConsolePortLK/releases/latest)** — UI, кольцо способностей, курсор, привязки.
2. Маппер **[WoWpadX](https://github.com/leoaviana/WoWpadX)** (предпочтительно) или [WoWmapperX](https://github.com/leoaviana/WoWmapperX) — геймпад → клавиши, которые читает клиент.

Это порт ConsolePort 1.9.17 под Lua API WotLK, не розничный ConsolePort с CurseForge.

## Установка

1. Скачайте zip ConsolePortLK, распакуйте **все** папки (`ConsolePort`, `ConsolePortBar` и остальные) в `Interface/AddOns/`.
2. Поставьте WoWpadX, подключите геймпад (Xbox / DualShock / DualSense / Switch Pro).
3. Запустите сначала WoWpadX, затем `Wow.exe`.
4. В игре аддон должен подхватить пресет. Команды:

```
/cp config
/cp type
/cp help
/cp recalibrate
/cp actionbar
```

5. Отключите Bartender4 / Dominos / другие панели — иначе две схемы кнопок.

Клавиатурные бинды не затираются навсегда: выключили ConsolePort → `/reload` → снова мышь и клавиатура.

## Рекомендации под наши варианты

- **Одинокий волк / NPCBots (пятёрка):** геймпад ок. Танк/хил с кольцом способностей удобнее, чем кликать 40-ман.
- **Playerbots:** рейд через аддон ботов почти всегда мышью (инвайт, роли, init). Геймпад годится для квестов и открытого мира; перед рейдом включите мышь или держите аддон ботов на второй панели монитора.
- Камера: правый стик в WoWpadX должен двигать мышь. Чувствительность крутите в WoWpadX, не в Windows «ускорение указателя».
- Чат на геймпаде неудобен — для `.playerbots` / `.npcbot` оставьте клавиатуру под рукой.

## Steam Deck / Proton

WoWpadX часто не видит `Wow.exe` в другом prefix. По очереди:

1. Одинаковый Proton у Wow и WoWpadX.
2. Launch Options WoWpadX: `WoWpadX.exe -l "/path/to/Wow.exe"`
3. У `Wow.exe`: `PROTON_REMOTE_DEBUG_CMD="/path/to/WoWpadX.exe" %command%`
4. В раскладках Steam шаблон `Gamepad leoaviana ConsolePortLK`. Имя игры в Steam: `World of Warcraft: WotLK`.

Подробности — README ConsolePortLK.

## Если ничего не биндится

- Клиент строго 3.3.5a 12340, не Classic.
- Аддон включён на экране выбора персонажа.
- После смены версии ConsolePortLK иногда чистят `WTF/` (полный сброс: `/cp resetall`).
- Кастомные клиенты с ломаным RestrictedEnvironment аддон не переваривает.
