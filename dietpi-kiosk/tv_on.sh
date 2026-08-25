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
