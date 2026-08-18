# Популярные аддоны для 3.3.5a (AzerothCore)

Ставьте сборки **именно под WotLK 3.3.5 / 12340**, не Classic и не Retail. Каталог: `Interface/AddOns/`.

## Нужны почти всегда

| Аддон | Зачем |
|---|---|
| [Questie](https://github.com/Questie/Questie) (ветка/релиз WotLK) | Квесты на карте. Удобно в прогрессии, когда мир «ванильный». |
| [AtlasLoot](https://www.curseforge.com/wow/addons/atlasloot-enhanced) 3.3.5 | Лутовые таблицы рейдов/данжей. |
| [Deadly Boss Mods](https://github.com/DeadlyBossMods/DeadlyBossMods) (WotLK) | Таймеры боссов. Для IP-Naxx40 часть модулей может врать — смотрите DBM-Naxx. |
| [Details!](https://github.com/Tercioo/Details-Damage-Meter) / Recount / Skada | Метр. Details тяжелее; Skada легче. |
| [Bagnon](https://www.wowace.com/projects/bagnon) 3.3.5 | Сумки в одном окне. |
| [Auctionator](https://github.com/dev7355608/Auctionator) (если есть сборка 3.3.5) или Auctioneer | Удобный АН вместе с AHBot. |
| [Leatrix Maps](https://www.curseforge.com/wow/addons/leatrix-maps) | Нормальная карта калимдора/восточных. |
| [Gatherer](https://www.curseforge.com/wow/addons/gatherer) + Routes | Трава/руда. Полезно, когда все профессии на одном чаре. |
| [Bartender4](https://www.wowace.com/projects/bartender4) / Dominos | Панели. С ConsolePort лучше **не** ставить второй action bar-аддон. |
| [Grid2](https://github.com/michaelnpsp/Grid2) / VuhDo / HealBot | Рейдовые фреймы. Для пятёрки NPCBots хватит дефолта или Grid. |
| [Omen](https://www.wowace.com/projects/omen-threat-meter) | Угроза. |
| [TellMeWhen](https://www.wowace.com/projects/tellmewhen) | Ауры/проки (WeakAuras на 3.3.5 штатно нет). |
| [Postal](https://www.wowace.com/projects/postal) | Почта. |
| [Spy](https://www.curseforge.com/wow/addons/spy) | Враги поблизости (на lonewolf с друзьями). |

## Individual Progression

- Аддон автора IP: [hide-vendor-price](https://github.com/ZhengPeiRu21/hide-vendor-price) — цены только у вендора, как до позднего WotLK.
- Optional client-patch из репозитория IP (`patch-V.mpq` / `patch-S.mpq`) — в `Data/` клиента, **не оба сразу**. Это рецепты/реагенты vanilla, не аддон.

## Только вариант Playerbots

Ботами командуют чатом; без UI это мучение. Берите одно:

- [список аддонов playerbots](https://github.com/mod-playerbots/mod-playerbots/wiki/Playerbot-Addons-and-Sub%E2%80%90Modules) — PlayerbotPanel, MultiBot и аналоги.
- Команды без аддона: `/invite Имя`, `.playerbots bot addclass warrior`, `/p follow`, `/ra grind`, `.playerbots bot init=rare Имя`.

Не ставьте аддоны NPCBots (другой тип существ).

## Только вариант NPCBots

- Аддоны из [Trinity-Bots](https://github.com/trickerer/Trinity-Bots) (раздел Addons): фреймы/кнопки найма.
- Найм и так работает через gossip у спавнов и `.npcbot`.

## Геймпад

Отдельно: [docs/consoleport.md](consoleport.md). С Bartender/Dominos и ConsolePortLK одновременно — конфликт панелей.

## Что не ставить

- ElvUI Retail / Dragonflight.
- WeakAuras 5.x.
- Аддоны Cataclysm+.
- Несколько угрозометров сразу.
