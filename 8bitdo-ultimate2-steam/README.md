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

Если хотите максимально узко (без wake от любых USB устройств), включите `power/wakeup`
только для USB-узла донгла, когда он в idle-режиме **`2dc8:6013`**.

1) Оставьте геймпад **выключенным** или положите на док (чтобы донгл был в `6013`).  
2) Выполните:

```bash
# Включить wakeup только для устройств VID=2dc8 PID=6013 (idle донгл)
for d in /sys/bus/usb/devices/*; do
  [[ -f "$d/idVendor" && -f "$d/idProduct" && -f "$d/power/wakeup" ]] || continue
  vid="$(tr '[:upper:]' '[:lower:]' <"$d/idVendor" 2>/dev/null | tr -d '[:space:]')"
  pid="$(tr '[:upper:]' '[:lower:]' <"$d/idProduct" 2>/dev/null | tr -d '[:space:]')"
  if [[ "$vid" == "2dc8" && "$pid" == "6013" ]]; then
    echo enabled | sudo tee "$d/power/wakeup" >/dev/null
    echo "enabled: $d (2dc8:6013)"
  fi
done
```

Если у вас wake нужно и для других состояний, повторите для PID `6012` и/или `310b`
(заменив `6013` в скрипте).

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

Не ставьте `ATTR{authorized}="0"` на `6013`: донгл должен оставаться на шине и для Steam-hide, и для wait/wake.

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

## Варианты решения бага Steam

От простого к продвинутому. Можно комбинировать **1 + 2**, при необходимости добавить **3** или **4**.

### Вариант 1 — Blacklist пустого донгла в Steam

**Файлы:** `steam/config-snippet.vdf.example`, `environment/99-8bitdo.conf`

Steam не должен открывать `2dc8:6013`. Первое «живое» устройство на порту — уже `6012`.

```bash
# SDL ignore (Game Mode / Bazzite)
mkdir -p ~/.config/environment.d
cp environment/99-8bitdo.conf ~/.config/environment.d/
# Перелогин или reboot

# Steam blacklist — вручную, Steam должен быть закрыт!
# Добавить в ~/.local/share/Steam/config/config.vdf (или ~/.steam/steam/config/config.vdf):
#   "controller_blacklist" "2dc8/6013"
```

**Wake PC:** не влияет (Steam не участвует в USB wake).

---

### Вариант 2 — udev: скрыть HID у пустого донгла `6013` (рекомендуется)

**Файл:** `udev/71-8bitdo-hide-dummy.rules`

Донгл остаётся на USB, но `/dev/hidraw*` и `/dev/input/event*` для `6013` недоступны — Steam не на чём «залипнуть».

```bash
sudo cp udev/71-8bitdo-hide-dummy.rules /etc/udev/rules.d/
sudo udevadm control --reload
sudo udevadm trigger
```

Проверка (геймпад выключен): `lsusb` показывает `6013`, в Steam устройства нет.  
Включили D-Input → сразу полный Ultimate 2 без Restart Steam.

**Wake PC:** не влияет (USB-устройство на шине остаётся, wake по переходу `6013→6012` работает).

Практика с железом: если подключить контроллер **сразу** в D-Input (`6012`) и Steam всё равно не показывает extended-клавиши/гиро (а переподключение/выключение-заново `6012` не помогает), причина в том, что Steam не переинициализирует обработчик, если **PID не менялся**. Решение:
- либо сделать цикл **XInput → D-Input** (310b → 6012): после смены ID Steam обычно «просыпает» mapping;
- либо включить **вариант 4** (Auto-reset на `6012`), чтобы форсировать disconnect/reconnect и тем самым заставить Steam перечитать устройство.

---

### Вариант 3 — udev: unbind HID-драйвера для `6013`

**Файл:** `udev/72-8bitdo-unbind-dummy.rules`

Жёстче варианта 2: пустой донгл без HID-драйвера. При включении геймпада появляется новое устройство `6012`.

```bash
sudo cp udev/72-8bitdo-unbind-dummy.rules /etc/udev/rules.d/
sudo udevadm control --reload
sudo udevadm trigger
```

**Wake PC:** не влияет.

> **Не используйте** `ATTR{authorized}="0"` на `6013` постоянно — донгл может перестать перечисляться в `6012`.

---

### Вариант 4 — Auto-reset USB при появлении `6012`

**Файлы:** `scripts/8bitdo-reenum.sh`, `udev/73-8bitdo-reenum.rules`

Софт-версия «вынуть/вставить донгл»: Steam видит disconnect → reconnect с чистым `6012`.

```bash
sudo cp scripts/8bitdo-reenum.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/8bitdo-reenum.sh
sudo cp udev/73-8bitdo-reenum.rules /etc/udev/rules.d/
sudo udevadm control --reload
sudo udevadm trigger
```

Минус: ~0.3 с обрыва при включении геймпада.  
**Wake PC:** не блокирует; срабатывает уже после пробуждения, возможен короткий reconnect.

---

### Вариант 5 — Ручной обход (без установки)

1. Вынуть 2.4 ГГц донгл из USB
2. Включить геймпад в D-Input (`B + Home`)
3. Вставить донгл
4. Steam видит полный контроллер

**Wake PC:** **ломает** — донгл вынут, некому слать USB wake.

---

## Влияние на пробуждение ПК (Wake-on-USB)

| Вариант | Wake при снятии с дока / включении геймпада |
|---------|---------------------------------------------|
| 1. Steam blacklist | ✅ Не влияет |
| 2. udev hide `6013` | ✅ Не влияет |
| 3. udev unbind `6013` | ✅ Не влияет |
| 4. Auto-reset `6012` | ✅ Wake OK, возможен короткий reconnect после пробуждения |
| 5. Вынуть донгл | ❌ Wake не работает |
| Держать геймпад всегда включённым | ⚠️ Может **не** разбудить (нет перехода `6013→6012`) |

### Требования для Wake-on-USB

См. раздел **[Пробуждение ПК геймпадом на Bazzite](#пробуждение-пк-геймпадом-на-bazzite-кратко)** в начале README.

Кратко: донгл **всегда в USB** во сне; wake по переходу `6013` → `6012`/`310b` при включении геймпада.

---

## Рекомендуемый порядок установки на Bazzite

```bash
cd 8bitdo-ultimate2-steam

# Wake от геймпада (если из коробки не будит)
sudo cp udev/10-wakeup-usb-hubs.rules /etc/udev/rules.d/

# Сон / док / wake без ложных пробуждений
sudo ./scripts/install-sleep.sh

# Steam: гиро и extra buttons (если ещё нет)
sudo cp udev/71-8bitdo-u2w.rules /etc/udev/rules.d/
sudo cp udev/71-8bitdo-hide-dummy.rules /etc/udev/rules.d/
mkdir -p ~/.config/environment.d
cp environment/99-8bitdo.conf ~/.config/environment.d/
# Steam blacklist при закрытом Steam: steam/config-snippet.vdf.example

sudo udevadm control --reload
sudo udevadm trigger
# Перелогин / reboot для environment.d
```

Если Steam всё ещё «глупый» → добавить вариант 3 или 4.

XInput auto-off **не** ставить отсюда (не проверено на железе).

---

## Проверка успеха

1. Донгл в USB, геймпад **выключен** → в Steam **нет** 8BitDo (или только после фикса — ничего)
2. `B + Home` → имя **«8BitDo Ultimate 2 Wireless Controller for PC»**
3. Controller settings → Test Device Inputs: **PL, PR, L4, R4, gyro**
4. **Без** Restart Steam

«Глупый» режим: имя **«8BitDo Ultimate 2 Wireless»** (без «Controller for PC»), нет гиро и extended buttons.

---

## Структура репозитория

```
8bitdo-ultimate2-steam/
├── README.md
├── config/8bitdo-sleep.conf
├── environment/99-8bitdo.conf
├── steam/config-snippet.vdf.example
├── systemd/8bitdo-suspend.conf
├── scripts/
│   ├── 8bitdo-common.sh
│   ├── 8bitdo-pre-suspend.sh
│   ├── 8bitdo-post-resume.sh
│   ├── install-sleep.sh
│   ├── uninstall-sleep.sh
│   └── 8bitdo-reenum.sh
└── udev/
    ├── 10-wakeup-usb-hubs.rules      # Wake-on-USB для root hubs
    ├── 71-8bitdo-u2w.rules
    ├── 71-8bitdo-hide-dummy.rules
    ├── 72-8bitdo-unbind-dummy.rules
    └── 73-8bitdo-reenum.rules

Удалено: `8bitdo-xinput-poweroff-experimental/`
```

---

## Ссылки

- [steam-for-linux#12989](https://github.com/ValveSoftware/steam-for-linux/issues/12989) — баг D-Input до рестарта Game Mode
- [steam-for-linux#12154](https://github.com/ValveSoftware/steam-for-linux/issues/12154) — extended buttons / hidraw
- [steam-devices#64](https://github.com/ValveSoftware/steam-devices/issues/64) — udev для Ultimate 2
- [Gist: Ultimate 2 on Linux](https://gist.github.com/barraIhsan/783a82bcf32bed896c85d27dbb8018a5)
- [8bitdo-sleep-fix](https://github.com/jasonewall/8bitdo-sleep-fix) — unbind + wait idle (у нас wait без unbind)
- [wake-on-2.4g](https://github.com/Redemp/wake-on-2.4g) — waitdock / idle PID
