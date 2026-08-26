#!/bin/bash
# Wake TV: WOL + ADB screen-on
# Target: /root/tv_on.sh

set -euo pipefail

# Пробуждаем сетевую карту ТВ пакетом WOL
etherwake -i eth0 d4:5e:ec:f5:01:0d
sleep 2

# Подключаемся по ADB
adb connect 192.168.0.2:5555
sleep 1

# Посылаем команду пробуждения экрана (KEYCODE_WAKEUP)
adb shell input keyevent 224
sleep 1

# Переключаем вход на HDMI 3 (KEYCODE_TV_INPUT_HDMI_3)
adb shell input keyevent 245
