#!/bin/bash
# Wake Xiaomi TV: WOL + ADB screen-on + switch to HDMI 3
# Target: /root/tv_on.sh

set -euo pipefail

TV_ADB="192.168.0.2:5555"
# Xiaomi ExternalSourceActivity: HDMI1=23, HDMI2=24, HDMI3=25 (проверьте на своей модели)
XIAOMI_HDMI3_INPUT=25

# Пробуждаем сетевую карту ТВ пакетом WOL
etherwake -i eth0 d4:5e:ec:f5:01:0d
sleep 2

# Подключаемся по ADB
adb connect "$TV_ADB"
sleep 1

# Посылаем команду пробуждения экрана (KEYCODE_WAKEUP)
adb shell input keyevent 224
sleep 2

# Переключаем вход на HDMI 3 (Xiaomi)
# 1) родной плеер Xiaomi
# 2) DroidLogic passthrough (многие Mi TV на Amlogic)
# 3) запасной keyevent
switch_hdmi3() {
  adb shell am start -n com.xiaomi.mitv.tvplayer/com.xiaomi.mitv.tvplayer.ExternalSourceActivity \
    --ei input "$XIAOMI_HDMI3_INPUT" && return 0
  adb shell am start -a android.intent.action.VIEW \
    -d 'content://android.media.tv/passthrough/com.droidlogic.tvinput/.services.Hdmi3InputService/HW7' && return 0
  adb shell input keyevent 245
}

switch_hdmi3 || true
