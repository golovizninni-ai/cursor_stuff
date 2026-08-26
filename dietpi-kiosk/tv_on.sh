#!/bin/bash
# Wake Xiaomi (MediaTek) TV: WOL + ADB screen-on + switch to HDMI 3
# Target: /root/tv_on.sh

set -euo pipefail

TV_ADB="192.168.0.2:5555"

etherwake -i eth0 d4:5e:ec:f5:01:0d
sleep 2

adb connect "$TV_ADB"
sleep 1

# KEYCODE_WAKEUP
adb shell input keyevent 224
sleep 2

# Xiaomi source picker -> tap HDMI 3 tile
adb shell am start -a com.mitv.tvhome.atv.app.tv.INPUTSOURCE_POPUP
sleep 1
# UI grid tile "HDMI 3" bounds [480,280][800,540] @ 1920x1080
adb shell input tap 640 410
