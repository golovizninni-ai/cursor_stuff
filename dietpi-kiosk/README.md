# DietPi SOC dashboard kiosk

Кастомизации для слабенького Intel NUC у ТВ: один Chromium с тремя дашбордами, авторотация вкладок, VNC на тот же экран (`:0`), без курсора.

## Дашборды

1. `https://alfa-soc.vls.lan/`
2. `https://alfa-siem-pt.vls.lan/#/dashboards/dashboard?dashboardId=74`
3. `https://zabbix-ib.vls.lan/`

Интервал ротации: **45 секунд**.

## Файлы

| Файл | Куда на NUC |
|---|---|
| `chromium-autostart.sh` | `/var/lib/dietpi/dietpi-software/installed/chromium-autostart.sh` |
| `kiosk-session.sh` | `/usr/local/bin/kiosk-session.sh` |
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

## VNC (экран ТВ)

- Хост: IP NUC
- Порт: **5900** (в MobaXterm — отдельное поле порта, не `IP:5900` в строке хоста)
- Пользователь сессии: `dietpi`
- Пароль: заданный через `tigervncpasswd`

VNC и ротация стартуют из той же X-сессии, что и Chromium (не отдельными systemd-юнитами), чтобы не гоняться с автологином DietPi после reboot.

## Полезные правки

- Разрешение: `SOFTWARE_CHROMIUM_RES_X/Y` в `/boot/dietpi.txt` → `1920` / `1080`
- Смена интервала вкладок: `sleep 45` в `kiosk-session.sh`
- Самоподписанные сертификаты `.vls.lan`: флаги `--ignore-certificate-errors --allow-insecure-localhost`
- Плашка «Restore pages?»: сброс `Preferences` + `--hide-crash-restore-bubble`

## Замечания

- Не используйте `--incognito` — слетят логины после reboot.
- `--kiosk` глушит `Ctrl+Page_Down`; используем `--start-fullscreen`.
- `dietpi-software reinstall` Chromium может затереть `chromium-autostart.sh` — после переустановки снова скопируйте файл из этого каталога.
