# IR через 3.5mm jack на этом NUC

## Железо NUC (проверено)

- Кодек: **ALC255 Analog** `hw:0,0`
- Headphone Jack: **on**
- Допустимые rate аналога: **44100–48000 Hz только**
- Nyquist ≈ **24 kHz**

Классический ИК-приёмник ТВ ждёт оптическую несущую **~36–38 kHz**.  
Её **нельзя** честно выдать с этого jack: `plughw` ресемплит WAV 192 kHz → 48 kHz и **убивает несущую**. Громкость / softvol / стерео это не лечат.

Итог эксперимента с усилением:

- full-scale stereo WAV, 36+38 kHz, IRBoost ≈ +20 dB — залито и проигрывается;
- ТВ по ADB после блэста **не гаснет** → jack IR Power на этой связке **не работает**.

## Что делать для cold boot

1. **USB IR-blaster** (`/dev/lirc0` + `ir-ctl`) — предпочтительно  
2. **Умная розетка** / реле на питании ТВ  
3. Soft wake как сейчас: **WOL + ADB** (только standby, не cold)

## Файлы (оставлены для эксперимента)

| Path | Purpose |
|---|---|
| `/root/ir/generate-xiaomi-power-wav.py` | генератор WAV |
| `/root/ir/xiaomi_power_38k.wav` | boosted stereo |
| `/root/tv_ir_power.sh` | aplay + softvol (с WARN про 48 kHz) |
| `/root/test-ir-cycle.sh` | строгий тест без WOL |
