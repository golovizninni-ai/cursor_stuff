# IR Power через 3.5mm jack (без USB)

На NUC: **ALC255 Analog** (`plughw:0,0`). USB IR не используется.

## Железо

1. Воткните ИК-передатчик с джеком в **наушники** NUC (не mic).  
2. Направьте светодиод в ИК-окно Xiaomi (близко, прямо, без стекла под углом).  
3. Громкость ALSA поднимается скриптом на 100% при отправке.

## Генерация WAV

Код Power — Xiaomi RC-MM variant (`D=0x3C F=0xCC`), несущая 36 kHz:

```bash
python3 /root/ir/generate-xiaomi-power-wav.py /root/ir/xiaomi_power.wav
```

`install.sh` делает это автоматически.

## Проверка

```bash
# ТВ cold/off, смотрите на экран
/root/tv_ir_power.sh

# полный cold path
/root/tv_on.sh
```

Если не включает:

- проверьте, что джек в **output**, LED смотрит в приёмник;
- `aplay -l` — должен быть `card 0: PCH ... device 0: ALC255 Analog`;
- смените устройство: `IR_ALSA_DEVICE=plughw:0,0 /root/tv_ir_power.sh`;
- протокол у моделей Xiaomi отличается — тогда нужен другой D/F в `generate-xiaomi-power-wav.py` или умная розетка.

## Файлы

| Path | Purpose |
|---|---|
| `/root/ir/xiaomi_power.wav` | ИК Power как звук |
| `/root/ir/generate-xiaomi-power-wav.py` | генератор WAV |
| `/root/tv_ir_power.sh` | `aplay` на jack |
| `/root/tv_on.sh` | cold: WOL + IR jack + wait ADB + HDMI 3 |
