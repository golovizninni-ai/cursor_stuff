# DietPi SOC dashboard kiosk

Кастомизации Intel NUC у ТВ: Chromium в **4K (3840×2160@30)**, три дашборда Grafana/Zabbix, авторотация вкладок, ночной F5-refresh, без курсора.

Перед стартом киоска вызывается **`/root/tv_on.sh`**: WOL на MAC ТВ + ADB wake (`192.168.0.2:5555`).

## Дашборды

1. Grafana SOC (kiosk): `https://alfa-soc.vls.lan/?orgId=1&...&kiosk/`
2. Grafana MaxPatrol обзор (kiosk): `https://alfa-soc.vls.lan/d/mp-overview/maxpatrol-e28094-obzor?...&kiosk`
3. Zabbix: `https://zabbix-ib.vls.lan/`

Интервал ротации: **45 секунд**. Вывод: **HDMI-1, 3840×2160@30** через `xrandr`.

## Файлы

| Файл | Куда на NUC |
|---|---|
| `chromium-autostart.sh` | `/var/lib/dietpi/dietpi-software/installed/chromium-autostart.sh` |
| `kiosk-session.sh` | `/usr/local/bin/kiosk-session.sh` |
| `refresh-dashboards.sh` | `/usr/local/sbin/refresh-dashboards.sh` |
| `tv_on.sh` | `/root/tv_on.sh` |
| `tv_off.sh` | `/root/tv_off.sh` |
| `install.sh` | запускается один раз на NUC |

## Установка на DietPi

Предпосылки: установлен Chromium (`dietpi-software`), autostart `11 : Chromium`, опционально TigerVNC.

```bash
# на NUC, от root
cd /path/to/dietpi-kiosk
chmod +x install.sh
./install.sh
reboot
```

Или вручную:

```bash
apt install -y xdotool unclutter tigervnc-scraping-server
cp kiosk-session.sh /usr/local/bin/kiosk-session.sh
cp chromium-autostart.sh /var/lib/dietpi/dietpi-software/installed/chromium-autostart.sh
chmod +x /usr/local/bin/kiosk-session.sh \
  /var/lib/dietpi/dietpi-software/installed/chromium-autostart.sh
sudo -u dietpi tigervncpasswd   # если пароля ещё нет
dietpi-autostart                # выбрать 11 : Chromium
reboot
```

## VNC (опционально)

В текущем `kiosk-session.sh` VNC **закомментирован**. Чтобы включить, раскомментируйте блок `x0vncserver` в скрипте.

Альтернатива с паролем (как раньше):

```bash
x0vncserver -display :0 -localhost no -rfbport 5900 \
  -PasswordFile /home/dietpi/.config/tigervnc/passwd &
```

Подключение: IP NUC, порт **5900** (в MobaXterm — отдельное поле порта).

## Управление Android TV

| Скрипт | Действие |
|---|---|
| `/root/tv_on.sh` | WOL → ADB wake → **HDMI 3** (Xiaomi) |
| `/root/tv_off.sh` | ADB → shutdown broadcast или keyevent 223 (sleep) |

Требования на NUC: `etherwake`, `adb` (ставятся через `install.sh`). На ТВ: сеть ADB `192.168.0.2:5555`.

### HDMI 3 на Xiaomi

В `tv_on.sh` пробуются по очереди:

1. `com.xiaomi.mitv.tvplayer.ExternalSourceActivity --ei input 25` (HDMI1=23, HDMI2=24, HDMI3=25)
2. DroidLogic passthrough `Hdmi3InputService/HW7`
3. `keyevent 245` (запасной)

Если не переключает — узнать правильный `input` / URI на ТВ:

```bash
adb connect 192.168.0.2:5555
adb shell dumpsys tv_input
# вручную переключите на HDMI3 пультом, затем:
adb logcat -d | grep -iE 'ExternalSource|passthrough|HDMI|newSource'
```

Поправьте `XIAOMI_HDMI3_INPUT` или URI в `/root/tv_on.sh`.

Проверка:

```bash
/root/tv_on.sh
/root/tv_off.sh   # усыпить вручную
```

MAC, IP ADB и интерфейс `eth0` правятся в `tv_on.sh` / `tv_off.sh`.

## Ночной refresh дашбордов

Каждую полночь cron шлёт **F5** на активную вкладку каждые **30 секунд** в течение **3 минут** — подтягивает данные без перезапуска Chromium.

```bash
# crontab root (ставится через install.sh)
0 0 * * * /usr/local/sbin/refresh-dashboards.sh >>/var/log/refresh-dashboards.log 2>&1
```

Лог: `/var/log/refresh-dashboards.log`

Ручной запуск:

```bash
/usr/local/sbin/refresh-dashboards.sh
```

`XAUTHORITY=/home/dietpi/.Xauthority` — киоск крутится от пользователя `dietpi`, не root.

## Полезные правки

- Разрешение: `SOFTWARE_CHROMIUM_RES_X/Y` в `/boot/dietpi.txt` → `3840` / `2160`; выход HDMI: `xrandr --output HDMI-1 ...`
- Имя выхода HDMI (`HDMI-1`) проверьте: `xrandr | grep connected`
- Смена интервала вкладок: `sleep 45` в `kiosk-session.sh`
- Самоподписанные сертификаты `.vls.lan`: флаги `--ignore-certificate-errors --allow-insecure-localhost`
- Плашка «Restore pages?»: сброс `Preferences` + `--hide-crash-restore-bubble`

## Замечания

- Не используйте `--incognito` — слетят логины после reboot.
- `--kiosk` глушит `Ctrl+Page_Down`; используем `--start-fullscreen`.
- `dietpi-software reinstall` Chromium может затереть `chromium-autostart.sh` — после переустановки снова скопируйте файл из этого каталога.
