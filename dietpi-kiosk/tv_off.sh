#!/bin/bash
# Sleep TV via ADB
# Target: /root/tv_off.sh

set -euo pipefail

# Проверяем, подключен ли ADB. Если нет — подключаемся
adb devices | grep -q "192.168.0.2:5555" || adb connect 192.168.0.2:5555
sleep 1

# Безопасное выключение: отправка команды "Уйти в сон"
adb shell am broadcast -a android.intent.action.REQUEST_SHUTDOWN || true
# Альтернативный вариант для Android TV (KEYCODE_SLEEP)
adb shell input keyevent 223
