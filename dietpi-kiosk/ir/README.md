# USB IR для cold power-on Xiaomi

Аудио-джек на этом NUC **не используется** (ALC255 Analog max 48 kHz — несущую 38 kHz не пропускает).

## После покупки USB IR

1. Вставить USB IR blaster (лучше RX+TX) в NUC.  
2. Проверить: `ls -l /dev/lirc*`  
3. Снять Power с родного пульта:

```bash
apt-get install -y v4l-utils
/root/ir/capture-xiaomi-power.sh
# нажать Power на пульте Xiaomi один раз
```

4. Проверка:

```bash
/root/tv_ir_power.sh
/root/test-ir-cycle.sh   # ADB off -> USB IR on -> poll ADB (без WOL)
```

## Хуки в скриптах

| Script | USB IR hook |
|---|---|
| `/root/tv_ir_power.sh` | `ir-ctl --send /root/ir/xiaomi_power.ir` или `irsend` |
| `/root/tv_on.sh` | cold path вызывает `tv_ir_power.sh` перед wait ADB |
| `/root/tv_off.sh` | `IR_POWER=1` — доп. IR toggle |
| `/root/ir/capture-xiaomi-power.sh` | запись `xiaomi_power.ir` |

Пока `/dev/lirc*` нет — `tv_ir_power.sh` пишет WARN и выходит с кодом 1; soft wake (ADB/WOL) продолжает работать.
