# Совместимость с Bazzite 44 (Deck / HTPC)

Bazzite **Deck 44** — крупная замена стека: **SteamOS-Manager**, **InputPlumber**, Gamescope Session OGUI, ядро **7.2**.

## Что может сломаться из наших скриптов

| Компонент | Риск на 44 | Почему | Действие |
|-----------|------------|--------|----------|
| **Guide+LT+RT → Game Mode** | Средний | `return-to-gamemode` → `steamosctl`; fallback `steamos-session-select` без args ещё ок, но лучше явный `steamosctl` | Ставить wrapper из этой папки |
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
