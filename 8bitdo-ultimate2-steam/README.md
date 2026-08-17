# 8BitDo Ultimate 2 Wireless — D-Input и Steam на Bazzite / SteamOS

Решения для работы **8BitDo Ultimate 2 Wireless** (2.4 ГГц донгл) в режиме **D-Input** со Steam Input: гироскоп, L4/R4, PL/PR без ручного Restart Steam.

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

- Донгл **всегда в USB** во сне
- BIOS: **Wake on USB**, отключить **ErP/EuP** если USB «мертвый» в сне
- Включить wakeup на порту донгла:

```bash
# Найти устройство
lsusb | grep -i 8bitdo
# Пример (путь зависит от системы):
echo enabled | sudo tee /sys/bus/usb/devices/1-2/power/wakeup
```

Цепочка wake: сон → донгл `6013` в USB → включили геймпад → PID `6012` → USB-событие → ПК просыпается.

---

## Рекомендуемый порядок установки на Bazzite

```bash
# 1. Права hidraw (если гиро не работает даже после фикса Steam)
sudo cp udev/71-8bitdo-u2w.rules /etc/udev/rules.d/

# 2. Скрыть пустой донгл
sudo cp udev/71-8bitdo-hide-dummy.rules /etc/udev/rules.d/

# 3. SDL ignore для Game Mode
mkdir -p ~/.config/environment.d
cp environment/99-8bitdo.conf ~/.config/environment.d/

# 4. Steam blacklist (Steam закрыт!)
# см. steam/config-snippet.vdf.example

sudo udevadm control --reload
sudo udevadm trigger
# Перелогин / reboot для environment.d
```

Если Steam всё ещё «глупый» → добавить вариант 3 или 4.

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
├── environment/
│   └── 99-8bitdo.conf          # SDL ignore для Game Mode
├── steam/
│   └── config-snippet.vdf.example
├── scripts/
│   └── 8bitdo-reenum.sh        # USB reset при появлении 6012
└── udev/
    ├── 71-8bitdo-u2w.rules           # hidraw uaccess
    ├── 71-8bitdo-hide-dummy.rules    # скрыть 6013 от Steam
    ├── 72-8bitdo-unbind-dummy.rules  # unbind hid для 6013
    └── 73-8bitdo-reenum.rules        # trigger reset на 6012
```

---

## Ссылки

- [steam-for-linux#12989](https://github.com/ValveSoftware/steam-for-linux/issues/12989) — баг D-Input до рестарта Game Mode
- [steam-for-linux#12154](https://github.com/ValveSoftware/steam-for-linux/issues/12154) — extended buttons / hidraw
- [steam-devices#64](https://github.com/ValveSoftware/steam-devices/issues/64) — udev для Ultimate 2
- [Gist: Ultimate 2 on Linux](https://gist.github.com/barraIhsan/783a82bcf32bed896c85d27dbb8018a5)
