# DietPi SOC dashboard kiosk

Кастомизации Intel NUC у ТВ: Chromium в **4K (3840×2160@30)**, три дашборда Grafana/Zabbix, авторотация вкладок, ночной F5-refresh, без курсора.

Перед стартом киоска вызывается **`/root/tv_on.sh`**: soft wake (ADB) или cold path (WOL + **USB IR Power** + ожидание ADB) → HDMI 3.

## Дашборды

1. Grafana SOC (kiosk): `https://alfa-soc.vls.lan/?orgId=1&...&kiosk/`
2. Grafana MaxPatrol обзор (kiosk): `https://alfa-soc.vls.lan/d/mp-overview/maxpatrol-e28094-obzor?...&kiosk`
3. Zabbix: `https://zabbix-ib.vls.lan/`

Интервал ротации: из `/etc/kiosk/dashboards.json` (по умолчанию **45 с**). Вывод: **HDMI-1, 3840×2160@30** через `xrandr`.

Список URL и ротация правятся во вкладке **Дашборды** веб-панели (или вручную в JSON).

## Файлы

| Файл | Куда на NUC |
|---|---|
| `chromium-autostart.sh` | `/var/lib/dietpi/dietpi-software/installed/chromium-autostart.sh` |
| `kiosk-session.sh` | `/usr/local/bin/kiosk-session.sh` |
| `kiosk-rotate.sh` | `/usr/local/sbin/kiosk-rotate.sh` |
| `dashboards.json` | `/etc/kiosk/dashboards.json` |
| `refresh-dashboards.sh` | `/usr/local/sbin/refresh-dashboards.sh` |
| `tv_on.sh` | `/root/tv_on.sh` |
| `tv_ir_power.sh` | `/root/tv_ir_power.sh` (USB IR hook) |
| `tv_off.sh` | `/root/tv_off.sh` |
| `tv_message.sh` | `/root/tv_message.sh` |
| `tv_healthcheck.sh` | `/root/tv_healthcheck.sh` |
| `tv_hdmi_watchdog.sh` | `/root/tv_hdmi_watchdog.sh` |
| `tv_panel/*` | `/usr/local/lib/tv_panel/` + `tv-panel.service` |
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
| `/root/tv_healthcheck.sh` | Раз в минуту (Пн–Пт 8:30–18:30): не Awake/Display ON или ADB down → вызывает `/root/tv_on.sh` |
| `/root/tv_hdmi_watchdog.sh` | Раз в 5 мин в том же окне: не HDMI 3 → popup + tap |
| `/root/ir/capture-xiaomi-power.sh` | Снять `xiaomi_power.ir` с пульта |

Автофикс: флаг `/root/tv_autofix.enabled` (есть = вкл). Без логов — только фикс. Cold IR из cron не вызывается. Во время `tv_message` (WebView) HDMI-watchdog не трогает вход.

Требования на NUC: `etherwake`, `adb`, `v4l-utils`. На ТВ: сеть ADB `192.168.0.2:5555`.

### Веб-панель

`https://ozii-dash.vls.lan/` — пульт (PWA: установка через значок в Chrome).  
`https://ozii-dash.vls.lan/message.html` — плашка/текст/секунды → `tv_message.sh`.  
`https://ozii-dash.vls.lan/dashboards.html` — вкладки ←/→, авторотация, URL, F5 / цикл 30с×3м, перезапуск киоска.

DNS: `ozii-dash.vls.lan` → `10.10.6.16`. TLS: wildcard `*.vls.lan` в `/etc/tv-panel/cert.pem` + `key.pem` (не в git).

Сервис: `systemctl status tv-panel`. Порт **443** (HTTPS).  
Вход: веб-форма + cookie (**90 дней**), PAM-пользователь **`pult`** (shell `nologin`, без sudo; `/etc/pam.d/tv-panel`).  
HTTP Basic не используется. `root` / `dietpi` в панели не принимаются.

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
/root/tv_message.sh
# Плашка сверху (Enter = пусто): ...
# Текст для ТВ (Enter = пусто): ...
# Сколько секунд показывать (0 = без таймера): 30
```

Плашка и текст могут быть пустыми (пустое поле просто не рисуется).

После N>0 секунд — обратно на **HDMI 3**. При `0` висит без таймера (Ctrl+C).

```bash
/root/tv_message.sh "Текст" 30
/root/tv_message.sh "Алерт" "" 15
/root/tv_message.sh "" "Только текст" 10
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
- Смена интервала вкладок: `rotate_sec` в `/etc/kiosk/dashboards.json` или вкладка Дашборды
- Самоподписанные сертификаты `.vls.lan`: флаги `--ignore-certificate-errors --allow-insecure-localhost`
- Плашка «Restore pages?»: сброс `Preferences` + `--hide-crash-restore-bubble`

## Замечания

- Не используйте `--incognito` — слетят логины после reboot.
- `--kiosk` глушит `Ctrl+Page_Down`; используем `--start-fullscreen`.
- `dietpi-software reinstall` Chromium может затереть `chromium-autostart.sh` — после переустановки снова скопируйте файл из этого каталога.
