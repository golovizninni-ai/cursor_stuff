# Совместимость с Bazzite 44 (Deck / HTPC)

Bazzite **Deck 44** — крупная замена стека: **SteamOS-Manager**, **InputPlumber**, Gamescope Session OGUI, ядро **7.2**.

## Что может сломаться из наших скриптов

| Компонент | Риск на 44 | Почему | Действие |
|-----------|------------|--------|----------|
| **Start+Select+LB+RB → Game Mode** | Средний | `return-to-gamemode` → `steamosctl`; лучше явный `steamosctl` | Ставить wrapper из этой папки |
| **Hotkey / Steam Input / D-Input** | **Высокий** | **InputPlumber** дублирует 8BitDo (второй «Steam Deck Controller»), может ломать маппинг и чтение evdev | **Ignore YAML** для `2dc8:6012` и `2dc8:310b` |
| Sleep / dock hooks | Низкий | `ExecStartPre`/`ExecStopPost` на suspend без изменений | Как на 43 |
| USB wake-only | Низкий | `power/wakeup` тот же; ядро 7.2 — проверить после обновления | `8bitdo-wakeup-check.sh` |
| USB re-enum (`6012`) | Низкий | udev + authorized reset — не зависят от steamos-manager | Как на 43 |
| hidraw udev | Низкий | uaccess как раньше | Как на 43 |

### Не ломается само по себе

- `systemd-suspend` drop-ins  
- `/sys/bus/usb/.../power/wakeup`  
- `73-8bitdo-reenum.rules`  
- `74-8bitdo-evdev.rules` (MODE 0666)

### Ломается / меняется поведение

1. **InputPlumber** — известный баг с 8BitDo Ultimate (дубли вводов).  
   Issues: [ublue-os/bazzite#5046](https://github.com/ublue-os/bazzite/issues/5046).  
2. **Переход в Game Mode** — только через `steamosctl` (нужен пакет `steamos-manager` на deck-образе).  
3. Имена сессий: `gamescope-session-ogui-steam.desktop` вместо старых `gamescope-session*.desktop`.

## Установка слоя 44

После обновления на Bazzite 44 **deck**:

```bash
cd 8bitdo-ultimate2-steam
sudo ./compat/bazzite44/scripts/install-bazzite44.sh
# перелогин / reboot рекомендуется (InputPlumber подхватывает yaml)
systemctl --user restart 8bitdo-gamemode-hotkey.service
```

Что ставит install:

1. InputPlumber ignore: `/etc/inputplumber/devices.d/19-custom-2dc8_{6012,310b}.yaml`  
2. Wrapper `/usr/local/bin/8bitdo-switch-gamemode` (`steamosctl` → `return-to-gamemode` → …)  
3. Обновляет `~/.config/8bitdo/gamemode.conf` → `switch_command` на wrapper  

Снятие: `sudo ./compat/bazzite44/scripts/uninstall-bazzite44.sh`

## После апдейта на 44 (типичные симптомы)

### Геймпад «сам заработал»
На 44 часто wake / D-Input / хоткеи уже ок **без** нашего installer (ядро 7.2 + новый стек). Слой `compat/bazzite44` всё равно полезен, если появятся **дубли** от InputPlumber.

### Автовход: Desktop (Plasma) сначала, Game Mode по ярлыку/хоткею
```bash
# мягко:
steamosctl set-default-login-mode desktop
steamosctl set-default-desktop-session plasma.desktop

# если после reboot всё равно Game Mode — жёстко (SDDM):
sudo ./scripts/fix-desktop-autologin.sh
sudo systemctl reboot
```
Скрипт пишет `Session=plasma.desktop` в `/etc/sddm.conf.d/zz-holo-autologin.conf` и создаёт `/etc/bazzite/desktop_autologin`.  
Проверка после reboot: не должно быть `Session=gamescope` в `grep -r Session /etc/sddm.conf.d/`.

### Ярлыки на рабочем столе просят sudo и ничего не делают
Старые `.desktop` с `pkexec` / `systemctl start return-to-gamemode` на 44 часто мёртвые. Нужен **`steamosctl` без sudo**:

```bash
./scripts/install-gamemode-desktop-shortcuts.sh
```

Или вручную: записать `OUTPUT_CONNECTOR=DP-1` (или `DP-3`) в `~/.config/environment.d/10-gamescope-session.conf` и `steamosctl switch-to-game-mode`.

### Game Mode на TV/мониторе идеален, Desktop OLED выбелен (SDR и HDR)
Известный глюк Steam/KWin: после Game Mode с HDR Desktop «серый», тумблер HDR в KDE не лечит. Обходы:

1. В Game Mode выключить HDR → перейти на Desktop (часто сразу норма).
2. Game Mode → Developer → **Принудительная компоновка** (Force Composite) — у части людей чинит Desktop (может снова ломать Game Mode до toggle HDR).
3. В KDE: Система → Дисплей → HDR / цветовой профиль на OLED — сброс профиля / «как у устройства».

Это не баг 8BitDo.

## Если дубли вводов всё равно есть

```bash
# временно (HTPC без встроенных кнопок handheld):
sudo systemctl disable --now inputplumber.service
# или через Bazzite Portal → Troubleshooting → InputPlumber
```

Либо официально: `sudo ujust` → генератор ignore (`bazzite-inputplumber-ignorelist`), если PID другие.

## Проверка после апдейта

```bash
# версия
rpm-ostree status | head -20
cat /usr/share/ublue-os/image-info.json

# steamosctl обязателен на deck 44
command -v steamosctl && steamosctl --help | head

# InputPlumber
systemctl is-active inputplumber.service
ls /etc/inputplumber/devices.d/

# наши хуки
./scripts/8bitdo-wakeup-check.sh
./scripts/8bitdo-gamemode-check-perms.sh
~/.local/bin/8bitdo-gamemode-hotkey.py --list-devices
```

## Откат 44 → 43

На Deck 44 откат **не всегда гладкий** (session management). Перед апдейтом:

```bash
sudo ostree admin pin 0
```

См. [анонс Deck 44](https://universal-blue.discourse.group/t/bazzites-biggest-update-deck-44-has-launched-happy-birthday-to-universal-blue/12373).
