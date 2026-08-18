# Полезные админ-команды в игре

Пишутся в чат с точки: `.gm on`. В консоли worldserver точка не нужна (`account create`).

Скрипты ставят `account set gmlevel ИМЯ 3 -1` — в игре хватает почти всего. Создание аккаунта друзьям — только консоль (уровень 4). Полный список ядра: [wiki AzerothCore](https://www.azerothcore.org/wiki/gm-commands). Здесь — то, что реально нужно на этом сервере.

`.help`, `.help teleport`, `.commands` — подсказка по тому, что доступно вашему gmlevel.

## Первый день

| Команда | Зачем |
|---|---|
| `.gm on` / `.gm off` | Флаг ГМ (невидимость к мобам, бейдж) |
| `.gm visible off` | Вас не видят игроки |
| `.gm fly on` | Полёт |
| `.gm chat on` | Бейдж ГМ в чате |
| `.server info` | Ревизия ядра, онлайн |
| `.save` / `.saveall` | Сохранить себя / всех |
| `.guid` | GUID выбранного персонажа (нужен для `setup-ahbot.sh`) |
| `.pinfo Имя` | Аккаунт, IP, персонаж |
| `.account` | Ваш gmlevel |

Аккаунт другу (консоль worldserver, не чат):

```
account create логин пароль
account set gmlevel логин 0 -1
```

Себе оставить 3. Друзьям — 0, иначе они тоже летают и спавнят шмот.

## Передвижение

Имена локаций и NPC — **английские** (серверные DBC enUS), даже на русском клиенте.

| Команда | Зачем |
|---|---|
| `.lookup teleport stormwind` | Найти имя точки |
| `.teleport Stormwind` | Телепорт (часто работает и `.tele`) |
| `.teleport name Друг Stormwind` | Телепортнуть оффлайн-персонажа |
| `.appear Имя` / `.summon Имя` | К игроку / игрока к себе |
| `.recall` | Назад, куда были до телепорта |
| `.unstuck Имя inn` | Друг застрял → таверна |
| `.gps` | Координаты, map/zone id |
| `.go xyz X Y Z mapId` | Точные координаты |
| `.go creature name Hogger` | К существу по имени |
| `.lookup creature hogger` | Найти entry NPC |
| `.lookup area stranglethorn` | ID зоны |

`.teleport` в Нордскенд/Запределье IP может запретить, пока тир персонажа не открыл континент — сначала `.ip set`, потом телепорт.

## Персонаж, шмот, профессии

Деньги в **меди**: `10000` = 1 золото. Отрицательное число снимает.

| Команда | Зачем |
|---|---|
| `.levelup 1` | +1 уровень (себе или выбранному) |
| `.character level Имя 60` | Поставить уровень, в том числе оффлайн |
| `.modify money 1000000` | +100г |
| `.modify speed all 3` | Скорость ×3 |
| `.gear repair` | Починить шмот выбранному |
| `.maxskill` | Скиллы (оружие, язык) на кап уровня |
| `.learn all recipes enchanting` | Все рецепты профессии (подставьте имя) |
| `.learn all my class` | Все заклинания и таланты класса |
| `.reset talents` | Сброс талантов |
| `.lookup item thunderfury` | ID предмета |
| `.additem 19019 1` | Выдать предмет |
| `.send items Имя "тема" "текст" 19019:1` | Почтой |
| `.mailbox` | Открыть почту без ящика |
| `.revive` | Воскресить выбранного / себя |
| `.die` | Убить выбранного (осторожно без цели — себя) |
| `.cooldown` | Снять КД |
| `.unaura #id` | Снять ауру по spell id с цели |
| `.combatstop` | Выйти из боя |
| `.cheat god on` / `.cheat power on` | Бессмертие / без маны (себе) |
| `.character customize` | Внешность на следующем логине |
| `.character rename` | Переименовать на следующем логине |
| `.character changefaction Имя` | Смена фракции |

Все профессии на одном чаре уже разрешены конфигом (`MaxPrimaryTradeSkill = 11`). Лишние кнопки клиент не рисует — макрос `/cast Enchanting` и т.д. `.learn all recipes` не выдаёт сам скилл, только рецепты, если профессия уже выучена у тренера.

## Инстансы и мир

| Команда | Зачем |
|---|---|
| `.instance unbind all` | Снять сейвы инстансов (себе / цели) |
| `.respawn` | Респавн ближайших мобов |
| `.npc info` | GUID/entry выбранного NPC |
| `.npc near 30` | Спавны рядом |
| `.lookup event` / `.event activelist` | Ивенты (AQ, вторжение) |
| `.reload config` | Перечитать `.conf` без рестарта (не все ключи) |
| `.announce текст` | Сообщение в чат всем |
| `.notify текст` | Сообщение на экран всем |

## Individual Progression

Тир **на персонаже**. `.ip set N` — N это **последний завершённый** тир, не «текущий контент». Цель: себя или выбранного игрока/бота. Поднять/опустить может только ГМ. Понижение тира снимает ачивки прогрессии (в журнале до релога могут висеть).

| Команда | Зачем |
|---|---|
| `.ip get` / `.ip view` | Текущий тир цели |
| `.ip set 6` | Поставить тир |
| `.individualprogression set 6` | То же |

| N (завершён) | Что открывается дальше |
|---|---|
| 0 / 1 | Старт: MC и Onyxia, кап 60 |
| 2 | BWL |
| 3 | Пре-AQ, ZG, военные поставки |
| 4 | Война AQ, AQ20/AQ40 |
| 5 | Силитус-квесты после К’Туна |
| 6 | Naxx 60, вторжение Плети |
| 7 | Пре-TBC у Тёмного портала |
| 8 | Запределье, кап 70, Каражан / Груул / Магтеридон |
| 9 | SSC / ТК |
| 10 | Хиджал / Чёрный храм |
| 12 | Солнечный Колодец |
| 13 | Нордскол, кап 80, Naxx80 / Око / ОС |
| 14 | Ульдуар |
| 15 | Колизей |
| 16 | ЦЛК |
| 17 | Рубиновое святилище |

Rndbot подтягивает тир, когда его инвайтят. AddClass-бота после инвайта выделите и сделайте `.ip set` как у себя.

Полная таблица тиров: [wiki IP](https://github.com/ZhengPeiRu21/mod-individual-progression/wiki/List-of-Progression-Tiers).

## AutoBalance

| Команда | Зачем |
|---|---|
| `.ab mapstat` | Сколько игроков модуль видит в инсте, множители |
| `.ab creaturestat` | Масштаб выбранного моба |
| `.ab getoffset` / `.ab setoffset 2` | Смещение сложности (± игроки) на весь сервер |
| `.reload config` | После правки `AutoBalance.conf` |

Если playerbots падают на БГ — в конфиге выключите `AutoBalance.Enable.Global` и перезапустите world (не всё из AB живёт через reload).

## AHBot

После `setup-ahbot.sh`. ID аукционов: **2** Alliance, **6** Horde, **7** нейтральный.

| Команда | Зачем |
|---|---|
| `.ahbotoptions help` | Список |
| `.ahbotoptions seller 1` / `0` | Включить / выключить продавца |
| `.ahbotoptions buyer 1` / `0` | Покупателя |
| `.ahbotoptions ahexpire 7` | Снять лоты бота с нейтрального АН |
| `.ahbotoptions maxitems 7 400` | Потолок лотов на этом АН |

Постоянные настройки — overlay `configs/common/mod_ahbot.overlay.conf` и персонаж-заглушка из `setup-ahbot.sh`, не rndbot.

## Модерация (друзья)

| Команда | Зачем |
|---|---|
| `.kick Имя причина` | Выкинуть |
| `.mute Имя 30 причина` | Чат на 30 минут (весь аккаунт) |
| `.unmute Имя` | Вернуть чат |
| `.freeze` / `.unfreeze` | Заморозить цель |
| `.ban account логин -1 причина` | Пермабан (`4d20h` — срок) |
| `.unban account логин` | Снять бан |
| `.lookup player account логин` | Найти персонажей аккаунта |
| `.whispers off` | Не принимать шепот от игроков |

## Только playerbots

Команды с точкой — ГМ/чат. Без точки — **шепот боту**, `/p` или `/ra` (английский).

| Команда | Зачем |
|---|---|
| `.playerbots bot addclass warrior` | Боевой бот класса (DK = `dk`). Лимит: `MaxAddedBots` |
| `.playerbots bot init=rare Имя` | Перекачать rndbot под ваш уровень, rare-шмот |
| `.playerbots bot add Имя` / `remove Имя` | Логин/логаут **альтбота** с вашего аккаунта |
| `.playerbots bot remove *` | Снять всех альтботов группы |
| `.playerbots bot refresh=raid *` | Снять сейвы инстов с альтботов рейда |

В `/p` или `/ra`:

| Чат ботам | Зачем |
|---|---|
| `follow` / `stay` / `flee` | За вами / стоять / бежать к вам |
| `attack` | Бить вашу цель |
| `grind` | Бить всё подходящее |
| `summon` | Призвать ботов к вам |
| `co +tank` / `co +heal` / `co +dps` | Роль в бою |
| `co ?` / `nc ?` | Какие стратегии включены |
| `nc +follow` | Снова следовать вне боя |
| `@tank follow` / `@heal stay` | Только роль |
| `leave` | Боты выходят из группы |
| `reset` | Сбросить текущее действие |

Классы `addclass`: `warrior paladin hunter rogue priest shaman mage warlock druid dk`.

Опция LLM-чата (Ollama, [ollama-chat.md](ollama-chat.md)):

| Команда | Зачем |
|---|---|
| шепот `/w Имя текст` | Бот отвечает по-русски |
| `.ollama reload` | Перечитать conf и личности |
| `.ollama personality list` | Список личностей |
| `.ollama personality set Имя Gamer` | Задать стиль бота |

Полный список: [wiki playerbots](https://github.com/mod-playerbots/mod-playerbots/wiki/Playerbot-Commands).

## Только npcbots

Сначала **заспавнить** бота в открытом мире (не в инсте), потом нанять gossip или `.npcbot add`.

| Команда | Зачем |
|---|---|
| `.npcbot` | Справка |
| `.npcbot lookup` | ID классов |
| `.npcbot lookup 1` | Воины (1=воин … 11=друид, 6=ДК) |
| `.npcbot lookup 1 1` | Только ещё не заспавненные |
| `.npcbot spawn 70001` | Поставить бота в мир (сохраняется в БД) |
| `.npcbot move` | Перенести выбранного к вам |
| `.npcbot add` | Нанять выбранного бесплатно |
| `.npcbot remove` | Уволить (шмот остаётся на боте) |
| `.npcbot free` | Снять владельца, шмот вам |
| `.npcbot delete` | Удалить спавн из мира и БД |
| `.npcbot list spawned` | Кто уже стоит в мире |
| `.npc add 70000` | NPC-наниматель (gossip «I need your services») |

У бота: правый клик / gossip — роли, экипировка. Статы: `/bonk` по боту.

Руководство: [Trinity-Bots README](https://github.com/trickerer/Trinity-Bots#npcbot-commands).

## Lonewolf

Ядро без ИИ. Те же `.gm`, `.teleport`, `.ip`, `.ab`, `.ahbotoptions`. Ботов нет.
