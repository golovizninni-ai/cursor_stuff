# 8BitDo Ultimate 2 Wireless — D-Input и Steam на Bazzite / SteamOS

Решения для работы **8BitDo Ultimate 2 Wireless** (2.4 ГГц донгл) в режиме **D-Input** со Steam Input: гироскоп, L4/R4, PL/PR без ручного Restart Steam.

## Пробуждение ПК геймпадом на Bazzite (кратко)

Из коробки Bazzite/Linux **не** будит 8BitDo по 2.4 ГГц донгл: у донгла нет remote-wakeup как у клавиатуры. **Bluetooth** кнопкой геймпада ПК тоже обычно **не** будит — рабочий путь: **донгл в USB**, wake по USB-событию на шине (вкл/выкл геймпада, смена PID `6013` ↔ `6012`/`310b`).

### 1. BIOS

- **Wake from USB** / **USB Wake Support** — включить
- **ErP / EuP / Deep S5** — выключить (иначе USB во сне без питания)

### 2. ACPI — USB-контроллеры

```bash
cat /proc/acpi/wakeup | grep -i XHC
```

Строки `XHC`, `XHC0`, `XHC1` … должны быть `*enabled`. Если `*disabled`:

```bash
echo XHC0 | sudo tee /proc/acpi/wakeup   # имя с вашей платы
```

На Gigabyte при «чёрный экран, вентиляторы крутятся» после сна — отдельно: `ujust _toggle-gigabyte-wake-fix` ([документация Bazzite](https://docs.bazzite.gg/General/issues_and_resolutions/)).

### 3. USB root hubs (минимум, часто достаточно)

Разово (до перезагрузки):

```bash
for d in /sys/bus/usb/devices/usb*/power/wakeup; do
  echo enabled | sudo tee "$d"
done
```

Постоянно:

```bash
sudo cp udev/10-wakeup-usb-hubs.rules /etc/udev/rules.d/
sudo udevadm control --reload && sudo udevadm trigger
```

Проверка: `cat /sys/bus/usb/devices/usb3/power/wakeup` → `enabled` (номер `usb3` у вас свой — смотрите `lsusb -t`, к какому Bus подключён донгл).

### 4. «Любое USB / PCIe» (если хабов мало — как при тесте BT + донгла)

```bash
# все USB-узлы с power/wakeup
for f in /sys/bus/usb/devices/*/power/wakeup; do
  echo enabled | sudo tee "$f"
done

# PCI (осторожно — может сразу будить после сна)
for f in /sys/bus/pci/devices/*/power/wakeup; do
  echo enabled | sudo tee "$f"
done
```

Широкий wakeup даёт **ложные** пробуждения (док, Home-off, внутренний BT). Внутренний Bluetooth-адаптер, если сам будит ПК после сна, лучше оставить `disabled`:

```bash
# пример: найти виновника
grep . /sys/bus/usb/devices/*/power/wakeup 2>/dev/null | grep enabled
lsusb -t
```

### Минимальный таргет: пробуждение только от донгла 8BitDo Ultimate 2

**Важно:** для wake сигнал идёт **донгл → hub → … → root hub (usbN) → XHC → CPU**.
Если `usbN` на пути к донглу **disabled**, проснётся **только кнопка питания** (ACPI), не геймпад.

Скрипт `8bitdo-wakeup-only-dongle.sh` (актуальная версия):
- **enabled** — все `2dc8:*` и **вся цепочка hub** от донгла до `usbN`
- **disabled** — мышь, клава, чужие dongle и hub **не на пути** к 8BitDo
- **enabled** — XHC в `/proc/acpi/wakeup`, если был disabled

```bash
cd 8bitdo-ultimate2-steam
sudo ./scripts/8bitdo-wakeup-only-dongle.sh
sudo ./scripts/8bitdo-wakeup-check.sh   # диагностика
```

На пути донгла должны быть **enabled** и `2dc8:6013` (или `6012`/`310b`), и `usb3` (номер ваш).

### Только донгл / геймпад + кнопка питания (без мыши и клавиатуры)

**Цель:** случайно не будить ПК, если подвинули что-то на столе  
(проводная клавиатура, Logitech G на USB-свистке, USB-BT-донгл).

**Будит:** 8BitDo, кнопка питания корпуса.  
**Не трогаем:** Wake-on-LAN / ethernet / PCI — скрипт меняет только USB `power/wakeup`.

**Кнопка питания** — ACPI, её отключать не нужно.

#### Быстро (разово, до перезагрузки)

```bash
cd 8bitdo-ultimate2-steam
sudo ./scripts/8bitdo-wakeup-only-dongle.sh
```

Скрипт: `enabled` на `2dc8:*` **и hub-путь до root**, `disabled` на остальных USB-устройствах.
Кнопка питания (ACPI) не затрагивается.

```bash
cd 8bitdo-ultimate2-steam
sudo ./scripts/8bitdo-wakeup-only-dongle.sh
sudo ./scripts/8bitdo-wakeup-check.sh
```

Просмотр без изменений: `sudo ./scripts/8bitdo-wakeup-only-dongle.sh --dry-run`

**Симптом «будит только кнопка питания»:** старая версия скрипта **отключала root hub** — wake с USB не доходил. Обновите скрипт из репо и перезапустите (см. `8bitdo-wakeup-check.sh`).

**Симптом «то только геймпад, то мышь/клава» (нестабильно):**

1. После **resume** ядро часто **сбрасывает** `power/wakeup` — клава снова `enabled`, пока не отработает `ExecStopPost` / udev `75-*`.
2. **`10-wakeup-usb-hubs.rules`** (раздел 3) **несовместим** с «только геймпад». `install-wakeup-only-dongle.sh` удаляет его.
3. Тест: усыпить → **сразу** пробовать wake. Между «проснулся» и «снова уснул» настройки могут быть дефолтными.
4. BT-клава — другой путь, скрипт не отключит.

```bash
sudo ./scripts/install-wakeup-only-dongle.sh
sudo ./scripts/8bitdo-wakeup-check.sh
journalctl -t 8bitdo-wakeup -b
```

#### Постоянно (после каждой загрузки)

```bash
sudo ./scripts/install-wakeup-only-dongle.sh
```

Снятие: `sudo ./scripts/uninstall-wakeup-only-dongle.sh`

#### Точечно: только известная мышь / клавиатура

Если не хотите трогать все USB, найдите узлы и выключите wake вручную:

```bash
lsusb
lsusb -t
# пример: мышь Logitech на 3-4, клавиатура на 3-3
echo disabled | sudo tee /sys/bus/usb/devices/3-4/power/wakeup
echo disabled | sudo tee /sys/bus/usb/devices/3-3/power/wakeup
# донгл 8BitDo — enabled (геймпад выключен, PID 6013)
echo enabled | sudo tee /sys/bus/usb/devices/5-1/power/wakeup
```

Проверка, кто ещё может будить:

```bash
grep -H . /sys/bus/usb/devices/*/power/wakeup 2>/dev/null | grep ':enabled'
```

#### Ограничения

| Устройство | Отключается через `power/wakeup`? |
|------------|-----------------------------------|
| USB-мышь / USB-клава / Logitech G свисток | Да — **цель** |
| USB Bluetooth-донгл | Да (leaf USB) |
| 8BitDo 2.4 ГГц (`2dc8`) | Нет — enabled |
| Hub-путь донгла → `usbN` | Нет — **должен быть enabled** |
| Кнопка питания корпуса | Нет — ACPI |
| Wake-on-LAN / ethernet / PCI | Нет — **скрипт не трогает** |
| BT-клавиатура / мышь | Часто **нет** — отдельный BT-адаптер; отключите wake на его USB-узле или BT в BIOS |
| Встроенная клава ноутбука | Может будить не через USB — смотрите `/proc/acpi/wakeup` |

### 5. Проверка

1. Донгл в USB, ПК в sleep (Big Picture → Sleep)
2. Снять геймпад с дока или **Home** / **B+Home**
3. ПК должен проснуться

### 6. Сон без ложного wake

Wake настроен — это только половина. Чтобы **док / Home-off не будили** ПК при засыпании, ставьте sleep-хуки из этого репо (раздел ниже): `sudo ./scripts/install-sleep.sh`.

---

## Проблема

| Симптом | Причина |
|---------|---------|
| Нужно держать **B** при включении | Контроллер по умолчанию стартует в **XInput** (`2dc8:310b`) |
| Steam не видит гиро и доп. кнопки | Steam «залипает» на пустом донгле **6013**, не реагирует на смену PID → **6012** |
| Помогает Restart Steam | [ValveSoftware/steam-for-linux#12989](https://github.com/ValveSoftware/steam-for-linux/issues/12989) |

### USB Product ID

| PID | Состояние |
|-----|-----------|
| `6013` | Донгл вставлен, геймпад **выключен** («глупый» D-Input) |
| `6012` | Геймпад включён в **D-Input** (гиро + extended buttons) |
| `310b` | Геймпад в **XInput** |

**Суть бага:** Steam запоминает профиль USB-порта по первому увиденному устройству (`6013`). Когда геймпад включается и PID меняется на `6012`, Steam не переинициализирует контроллер.

---

## Базовая настройка (обязательно)

### 1. Прошивка

Обновите **контроллер и 2.4 ГГц адаптер** через **Ultimate Software V2** на Windows.

- D-Input по 2.4 ГГц: прошивка контроллера **≥ 1.06**, адаптера **≥ 1.04**
- Обновление прошивки — только в **XInput** (`X + Home` при включении)

### 2. Включение D-Input

1. Снимите геймпад с зарядного дока
2. Удерживайте **Home ~3 сек** — выключение
3. Зажмите **B**, нажмите **Home**, держите **B** ещё ~2 сек

| Комбинация | Режим |
|------------|-------|
| **B + Home** | D-Input (`6012`) |
| **X + Home** | XInput (`310b`) |
| **Y + Home** | Switch |

Проверка: `lsusb | grep -i 8bitdo`

### 3. Запоминание D-Input через док (частичный обход)

1. Включите в D-Input (`B + Home`)
2. Положите на зарядный док
3. При следующем снятии с дока режим часто сохраняется **на сессию**

Полное выключение Home’ом снова требует `B + Home`. Постоянного «всегда D-Input при cold boot» у контроллера **нет**.

### 4. Прошивка: обнулить маппинг лопаток

В Ultimate Software V2 сбросьте назначения L4/R4/PL/PR — иначе они перебивают Steam Input.

### 5. Права hidraw (Bazzite обычно уже есть)

Нужны для гиро **после** того, как Steam уже увидел полный D-Input. Сами по себе Steam не «переинициализируют».

```bash
sudo cp udev/71-8bitdo-u2w.rules /etc/udev/rules.d/
sudo udevadm control --reload
sudo udevadm trigger
```

---

## Сон из Big Picture, док и wake (рабочая установка)

Цель: **будить ПК любым действием 8BitDo** (снятие с дока, Home, XInput, D-Input).  
При засыпании: положить на док или Home-off **не должно** снова разбудить ПК и не должно оставить его в полусне (экраны выкл, вентиляторы крутятся).

Автовыключения XInput **нет** — команда USB не проверена. После wake в XInput выключите Home и включите **Home+B**.

### Три сценария без хуков

| Что сделали | Результат |
|-------------|-----------|
| Не успели: ПК уже спал, потом док / Home-off | USB `6012`/`310b`→`6013` **будит** ПК |
| Док в момент freeze | Гонка USB → «ни сон ни работа» |
| Док **до** сна | Уже `6013`, сон нормальный |

USB не различает «включение» и «выключение». Поэтому: **дождаться idle до freeze** и/или **снова уснуть**, если разбудило выключение.

### Варианты (что выбрано)

| Вариант | В поставке |
|---------|------------|
| **B. Ждать `6013`, таймаут 20 с** | Да, `MODE=wait` по умолчанию. Уже на доке — сразу sleep |
| **A. Всегда 20 с** | Опция: `MODE=delay` в `/etc/8bitdo-sleep.conf` |
| **D. Ложный wake → снова sleep** | Да: уснули с живым падом, проснулись в `6013` |
| C. Unbind донгла | Нет (не проверено) |
| E. Выключить USB wakeup | Нет — сломает wake от 8BitDo |
| HID power-off при XInput | Нет (эксперимент удалён) |

Не ставьте `ATTR{authorized}="0"` на `6013` постоянно: донгл должен оставаться на шине для wait/wake. Краткий reset `authorized` только в `8bitdo-reenum.sh` при появлении `6012`.

### Установка sleep-хуков (Bazzite, ostree)

`/usr` read-only — файлы в `/usr/local` и `/etc`.

```bash
cd 8bitdo-ultimate2-steam
sudo ./scripts/install-sleep.sh
# конфиг: /etc/8bitdo-sleep.conf
```

Вручную:

```bash
sudo install -m 0755 scripts/8bitdo-pre-suspend.sh scripts/8bitdo-post-resume.sh /usr/local/bin/
sudo install -m 0644 scripts/8bitdo-common.sh /usr/local/lib/
sudo install -m 0644 config/8bitdo-sleep.conf /etc/8bitdo-sleep.conf
sudo mkdir -p /etc/systemd/system/systemd-suspend.service.d
sudo cp systemd/8bitdo-suspend.conf /etc/systemd/system/systemd-suspend.service.d/8bitdo.conf
sudo systemctl daemon-reload
```

`install-sleep.sh` также вешает хук на hybrid-sleep и suspend-then-hibernate.

Снятие: `sudo ./scripts/uninstall-sleep.sh`

### Конфиг `/etc/8bitdo-sleep.conf`

```
MODE=wait          # wait | delay
TIMEOUT=20         # секунд ждать 6013 в MODE=wait
SLEEP_DELAY=20     # пауза в MODE=delay
RESUSPEND_DELAY=2  # пауза перед повторным suspend
```

Пока Steam пишет «засыпаю», `ExecStartPre` держит freeze — это окно «успеть на док».

### Поведение после установки

- Геймпад уже на доке (`6013`) → sleep сразу.
- Геймпад включён → до 20 с ждём док/Home; не дождались — всё равно sleep, флаг «уснули активными».
- Проснулись в **D-Input или XInput** → остаёмся awake.
- Проснулись в **`6013`**, а уснули активными → через ~2 с снова sleep (док после сна).
- Уснули уже idle, wake от клавиатуры/питания → **не** усыпляем снова.

Лог: `journalctl -t 8bitdo-sleep -b`

### Проверка сна

1. На доке → sleep из Game Mode → сразу (или короткий settle) спит.
2. В руках, sleep, за ~20 с на док → сон, не полусон.
3. Не успели, док после сна → не просыпается насовсем (миг и снова sleep).
4. Сон, снятие / Home / XInput / `B+Home` → ПК просыпается и **остаётся** awake.
5. После XInput-wake геймпад **сам не гаснет** (рабочая версия).

Если зависон **без** касания геймпада — часто Gigabyte GPP / NVIDIA (`ujust _toggle-gigabyte-wake-fix`), не эти скрипты.

---

## Steam: гиро и extra buttons (D-Input)

Steam «залипает» на первом видении порта. Hide `6013`, blacklist и unbind **на этом железе не работают**: если сразу включить D-Input (`6012`), PID не меняется повторно, Steam не перечитывает устройство. Помогает только **USB reset порта** в момент появления `6012` (как вынуть/вставить донгл).

Цикл XInput → D-Input (`310b` → `6012`) тоже работает, потому что PID меняется. Выключение и повторный D-Input — нет.

### Рабочий фикс — auto-reset при `6012`

**Файлы:** `scripts/8bitdo-reenum.sh`, `udev/73-8bitdo-reenum.rules`

```bash
cd 8bitdo-ultimate2-steam
sudo ./scripts/install-reenum.sh
```

Скрипт ставит reset, **удаляет** старые `71-8bitdo-hide-dummy.rules` / `72-8bitdo-unbind-dummy.rules`, если они ещё лежат в `/etc`.

Снятие: `sudo ./scripts/uninstall-reenum.sh`

Минус: ~0.3 с обрыва при каждом включении в D-Input.  
Wake: не ломает; после пробуждения будет короткий reconnect.

Вручную без install-скрипта:

```bash
sudo install -m 0755 scripts/8bitdo-reenum.sh /usr/local/bin/
sudo cp udev/73-8bitdo-reenum.rules /etc/udev/rules.d/
sudo udevadm control --reload
sudo udevadm trigger
```

### Ручной обход (без скрипта)

1. Вынуть 2.4 ГГц донгл
2. Включить геймпад в D-Input (`B + Home`)
3. Вставить донгл

**Wake:** ломает, пока донгл вынут.

### Что убрано (не ставить)

| Было | Почему нет |
|------|------------|
| Steam `controller_blacklist` `2dc8/6013` | Steam всё равно не переинициализирует `6012` |
| SDL ignore `6013` | То же |
| udev hide HID `6013` | То же; сразу D-Input без смены PID |
| udev unbind `hid-generic` на `6013` | То же |

Если уже ставили пункты 1–3: см. **[Как убрать пункты 1–3](#как-убрать-пункты-13-на-всякий-случай)** ниже.

### Как убрать пункты 1–3 (на всякий случай)

Не трогает sleep-хуки, wake-only-dongle и auto-reset `6012`.

**Скрипт** (udev + SDL-файл; blacklist — подсказка в конце):

```bash
cd 8bitdo-ultimate2-steam
sudo ./scripts/uninstall-old-steam-workarounds.sh
```

**Вручную:**

```bash
# Пункт 2 / 3 — udev
sudo rm -f /etc/udev/rules.d/71-8bitdo-hide-dummy.rules \
           /etc/udev/rules.d/72-8bitdo-unbind-dummy.rules
sudo udevadm control --reload
sudo udevadm trigger

# Пункт 1 — SDL ignore
rm -f ~/.config/environment.d/99-8bitdo.conf
```

**Пункт 1 — Steam blacklist** (Steam полностью закрыт, затем правка):

```bash
# где лежит config (один из путей)
ls ~/.local/share/Steam/config/config.vdf \
   ~/.steam/steam/config/config.vdf \
   ~/.var/app/com.valvesoftware.Steam/.local/share/Steam/config/config.vdf \
   2>/dev/null

grep -n controller_blacklist ~/.local/share/Steam/config/config.vdf
```

- Если строка `"controller_blacklist" "2dc8/6013"` — удалить её целиком.
- Если в кавычках несколько ID через запятую — убрать только `2dc8/6013` (и лишнюю запятую).
- Пустое `"controller_blacklist" ""` можно оставить или удалить строку.

После правки `environment.d` — **перелогин или reboot**. После правки `config.vdf` — запустить Steam снова.

Проверка, что старых udev нет:

```bash
ls /etc/udev/rules.d/*8bitdo* 2>/dev/null
# ожидаемо: 73-8bitdo-reenum.rules, опционально 10-wakeup-usb-hubs.rules, 71-8bitdo-u2w.rules
# не должно быть: 71-8bitdo-hide-dummy.rules, 72-8bitdo-unbind-dummy.rules
```

---

## Влияние на пробуждение ПК (Wake-on-USB)

| Что | Wake при снятии с дока / включении |
|-----|-------------------------------------|
| Auto-reset `6012` | OK, короткий reconnect после wake |
| Вынуть донгл вручную | Нет, пока донгл вынут |
| Геймпад всегда включён | Может не разбудить (нет `6013`→`6012`) |

### Требования для Wake-on-USB

См. раздел **[Пробуждение ПК геймпадом на Bazzite](#пробуждение-пк-геймпадом-на-bazzite-кратко)** в начале README.

Кратко: донгл **всегда в USB** во сне; wake по переходу `6013` → `6012`/`310b` при включении геймпада.

---

## Рекомендуемый порядок установки на Bazzite

```bash
cd 8bitdo-ultimate2-steam

# Steam: гиро и extra buttons — единственный рабочий обход
sudo ./scripts/install-reenum.sh

# Wake от геймпада (если из коробки не будит)
sudo cp udev/10-wakeup-usb-hubs.rules /etc/udev/rules.d/

# Сон / док без ложных пробуждений
sudo ./scripts/install-sleep.sh

# hidraw, если гиро нет даже после reset (на Bazzite часто уже есть)
sudo cp udev/71-8bitdo-u2w.rules /etc/udev/rules.d/

sudo udevadm control --reload
sudo udevadm trigger
```

---

## Game Mode hotkey (Desktop)

**Задача:** после cold boot в Desktop Mode включить геймпад с дивана и перейти в Game Mode **без клавиатуры/мыши**.

**Комбо:** **Guide (Home) + LT + RT** — одновременно, ~0.4 с.

Работает в **XInput** (`310b`) и **D-Input** (`6012`). Слушает evdev через blocking `select()` — **~0% CPU** в простое. После успешного перехода служба **завершается** и не поднимается до следующего входа в Plasma.

### Установка

```bash
cd 8bitdo-ultimate2-steam
chmod +x scripts/install-gamemode-hotkey.sh scripts/uninstall-gamemode-hotkey.sh
./scripts/install-gamemode-hotkey.sh

# если Permission denied (типично на Bazzite — одной группы input мало):
sudo ./scripts/install-gamemode-hotkey-udev.sh
# включите геймпад, затем принудительно:
sudo /usr/local/bin/8bitdo-gamemode-chmod-evdev.sh
./scripts/8bitdo-gamemode-check-perms.sh
systemctl --user restart 8bitdo-gamemode-hotkey.service
```

Ожидаемо в check: `mode=666` (или `crw-rw-rw-`) и **`read: OK`**.

**Почему группа input / uaccess не хватает:**
- user systemd **не может** `SupplementaryGroups=` → exit 216/GROUP;
- `MODE=0660` требует группу `input`, которой у user-службы нет;
- `uaccess` ACL иногда не вешается на все event-узлы.

Решение: udev `74-8bitdo-evdev.rules` с **`MODE="0666"`** + `8bitdo-gamemode-chmod-evdev.sh` при появлении геймпада.

### Удаление

```bash
cd 8bitdo-ultimate2-steam
./scripts/uninstall-gamemode-hotkey.sh
```

### Проверка

```bash
# найденные event-узлы и маппинг кнопок
~/.local/bin/8bitdo-gamemode-hotkey.py --list-devices

# статус и логи
systemctl --user status 8bitdo-gamemode-hotkey.service
journalctl --user -u 8bitdo-gamemode-hotkey.service -f
```

После комбо: `systemctl --user status` → **inactive (dead)**, exit 0. Снова активна после следующего входа в Desktop.

### Конфиг

`~/.config/8bitdo/gamemode.conf` — порог курков, `hold_ms`, путь к `return-to-gamemode`.

**Файлы:** `scripts/8bitdo-gamemode-hotkey.py`, `systemd/8bitdo-gamemode-hotkey.service`, `config/8bitdo-gamemode.conf`, `udev/74-8bitdo-evdev.rules`, `scripts/install-gamemode-hotkey-udev.sh`, `scripts/8bitdo-gamemode-check-perms.sh`

---

## Проверка успеха

1. `B + Home` (D-Input) — короткий обрыв USB, затем имя **«8BitDo Ultimate 2 Wireless Controller for PC»**
2. Controller settings → Test Device Inputs: **PL, PR, L4, R4, gyro**
3. **Без** Restart Steam и **без** цикла XInput → D-Input

«Глупый» режим: имя **«8BitDo Ultimate 2 Wireless»** (без «Controller for PC»), нет гиро и extended buttons.

---

## Структура репозитория

```
8bitdo-ultimate2-steam/
├── README.md
├── config/
│   ├── 8bitdo-sleep.conf
│   └── 8bitdo-gamemode.conf
├── systemd/
│   ├── 8bitdo-suspend.conf
│   ├── 8bitdo-wakeup-only-dongle.service
│   └── 8bitdo-gamemode-hotkey.service
├── scripts/
│   ├── 8bitdo-gamemode-hotkey.py
│   ├── install-gamemode-hotkey.sh
│   ├── uninstall-gamemode-hotkey.sh
│   ├── 8bitdo-reenum.sh
│   ├── install-reenum.sh
│   ├── uninstall-reenum.sh
│   ├── uninstall-old-steam-workarounds.sh
│   ├── 8bitdo-wakeup-only-dongle.sh
│   ├── install-wakeup-only-dongle.sh
│   ├── 8bitdo-common.sh
│   ├── 8bitdo-pre-suspend.sh
│   ├── 8bitdo-post-resume.sh
│   ├── install-sleep.sh
│   └── uninstall-sleep.sh
└── udev/
    ├── 10-wakeup-usb-hubs.rules
    ├── 71-8bitdo-u2w.rules
    ├── 73-8bitdo-reenum.rules
    └── 74-8bitdo-evdev.rules
```

---

## Ссылки

- [steam-for-linux#12989](https://github.com/ValveSoftware/steam-for-linux/issues/12989) — баг D-Input до рестарта Game Mode
- [steam-for-linux#12154](https://github.com/ValveSoftware/steam-for-linux/issues/12154) — extended buttons / hidraw
- [steam-devices#64](https://github.com/ValveSoftware/steam-devices/issues/64) — udev для Ultimate 2
- [Gist: Ultimate 2 on Linux](https://gist.github.com/barraIhsan/783a82bcf32bed896c85d27dbb8018a5)
- [8bitdo-sleep-fix](https://github.com/jasonewall/8bitdo-sleep-fix) — unbind + wait idle (у нас wait без unbind)
- [wake-on-2.4g](https://github.com/Redemp/wake-on-2.4g) — waitdock / idle PID
