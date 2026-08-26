# IR codes for Xiaomi TV cold power-on

NUC currently has **no USB IR** (`lsusb` / `/dev/lirc*` empty). Analog out is **ALC255** (`hw:0,0`) — suitable only for an experimental 3.5mm jack blaster.

## Recommended hardware

1. **USB IR blaster** (preferred for 24/7 kiosk) — creates `/dev/lirc0`, works with `ir-ctl`.
2. **3.5mm jack IR emitter** — experimental; needs a pre-recorded `xiaomi_power.wav` (38 kHz carrier). Unreliable on Intel NUC combo jacks.

## Capture Power from the original remote

On NUC after plugging USB IR RX/TX:

```bash
apt-get install -y v4l-utils
cp capture-xiaomi-power.sh /root/ir/
chmod +x /root/ir/capture-xiaomi-power.sh
/root/ir/capture-xiaomi-power.sh
# press Power on Xiaomi remote once
```

Produces `/root/ir/xiaomi_power.ir`. Test:

```bash
ir-ctl -d /dev/lirc0 --send=/root/ir/xiaomi_power.ir
# or
/root/tv_ir_power.sh
```

## Files

| Path on NUC | Purpose |
|---|---|
| `/root/ir/xiaomi_power.ir` | Raw pulse file for `ir-ctl` (create via capture) |
| `/root/ir/xiaomi_power.wav` | Optional experimental jack WAV |
| `/root/ir/xiaomi_power.ir.example` | Placeholder documenting expected format |
| `/root/tv_ir_power.sh` | Sends Power via ir-ctl / irsend / aplay |

## Confirm cold boot

After mains power returns, Xiaomi must turn on with **IR Power** from the original remote (Bluetooth remotes may not wake a fully dead TV). If remote Power works, this IR path will too once codes + blaster are in place.
