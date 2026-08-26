# DietPi SOC dashboard kiosk

Кастомизации Intel NUC у ТВ: Chromium в **4K (3840×2160@30)**, три дашборда Grafana/Zabbix, авторотация вкладок, ночной F5-refresh, без курсора.

Перед стартом киоска вызывается **`/root/tv_on.sh`**: soft wake (ADB) или cold path (WOL + **USB IR Power** + ожидание ADB) → HDMI 3.

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
| `tv_ir_power.sh` | `/root/tv_ir_power.sh` (USB IR hook) |
| `tv_off.sh` | `/root/tv_off.sh` |
| `test-ir-cycle.sh` | `/root/test-ir-cycle.sh` |
| `ir/*` | `/root/ir/` (capture + USB IR codes) |
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
| `/root/tv_on.sh` | Soft: ADB wake → HDMI 3. Cold: WOL + **USB IR Power** → wait ADB → wake → HDMI 3 |
| `/root/tv_ir_power.sh` | ИК Power через **USB** (`ir-ctl` / `irsend`) |
| `/root/tv_off.sh` | ADB sleep/shutdown; `IR_POWER=1` — ещё и USB IR toggle |
| `/root/tv_message.sh` | Вывести текст на ТВ через ADB (уведомление + HTML) |
| `/root/ir/capture-xiaomi-power.sh` | Снять `xiaomi_power.ir` с пульта |

Требования на NUC: `etherwake`, `adb`, `v4l-utils`. На ТВ: сеть ADB `192.168.0.2:5555`.

### Soft vs cold

| Состояние ТВ | Что работает |
|---|---|
| **Standby / sleep** (Android жив, сеть есть) | WOL + ADB — soft path |
| **Cold off** (моргнуло 220В) | **USB IR Power** + ожидание ADB (пока blaster не куплен — только пульт / розетка) |

### Холодный старт: USB IR

Аудио-джек **не используется**. После покупки USB IR:

```bash
ls -l /dev/lirc*
/root/ir/capture-xiaomi-power.sh   # Power на родном пульте
/root/tv_ir_power.sh
/root/test-ir-cycle.sh             # строгий тест без WOL
```

Подробности: [`ir/README.md`](ir/README.md).

### HDMI 3 на Xiaomi (MediaTek)

На этом ТВ нет рабочего `keyevent 245` / passthrough intent. Рабочая схема:

1. `am start -a com.mitv.tvhome.atv.app.tv.INPUTSOURCE_POPUP`
2. `input tap 640 410` — плитка **HDMI 3** в сетке (1920×1080)

Соответствие портов: HW2=HDMI1, HW3=HDMI2, HW4=HDMI3.

Проверка:

```bash
/root/tv_on.sh          # soft, если ТВ уже в сети
/root/tv_ir_power.sh    # только ИК Power
/root/tv_off.sh         # усыпить вручную
/root/tv_message.sh "Текст на весь экран"
TITLE="Алерт" DURATION_SEC=30 /root/tv_message.sh Проверка
```

MAC, IP ADB и интерфейс `eth0` правятся в `tv_on.sh` / `tv_off.sh` (`TV_ADB`, `TV_MAC`, `TV_IFACE`, `ADB_WAIT_SEC`).

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
