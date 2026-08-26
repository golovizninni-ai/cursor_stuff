#!/usr/bin/env python3
"""Generate boosted Xiaomi TV KEY_POWER WAV for 3.5mm IR blaster.

- Full-scale square carrier (max drive for passive IR LED)
- Stereo L+R (tip and ring both driven)
- Multiple frame repeats inside the file

Protocol (JP1 / IRP, Xiaomi RC-MM variant):
  {36k,290,msb}<2,-2|2,-3|2,-4|2,-5>(1000u,-2,D:8,F:8,C:4,2,^30m)*
  POWER: D=0x3C, F=0xCC

Usage:
  generate-xiaomi-power-wav.py [/root/ir/xiaomi_power.wav] [carrier_hz]
"""

from __future__ import annotations

import math
import struct
import sys
import wave
from pathlib import Path

UNIT_US = 290
SAMPLE_RATE = 192000
AMP = 32767  # full-scale int16 — max jack swing


def checksum(d: int, f: int) -> int:
    return ((d >> 4) ^ (d & 0xF) ^ (f >> 4) ^ (f & 0xF)) & 0xF


def encode_bits_msb(value: int, nbits: int) -> list[int]:
    bits = []
    for i in range(nbits - 1, -1, -1):
        bits.append((value >> i) & 1)
    return bits


def symbol_for_dibit(b1: int, b0: int) -> tuple[int, int]:
    idx = (b1 << 1) | b0
    return (2, -(2 + idx))


def build_timeline_us(d: int = 0x3C, f: int = 0xCC) -> list[tuple[bool, int]]:
    c = checksum(d, f)
    events: list[tuple[bool, int]] = []
    events.append((True, 1000))
    events.append((False, 2 * UNIT_US))

    bits = encode_bits_msb(d, 8) + encode_bits_msb(f, 8) + encode_bits_msb(c, 4)
    if len(bits) % 2:
        bits.append(0)

    for i in range(0, len(bits), 2):
        mark_u, space_u = symbol_for_dibit(bits[i], bits[i + 1])
        events.append((True, mark_u * UNIT_US))
        events.append((False, abs(space_u) * UNIT_US))

    events.append((True, 2 * UNIT_US))
    total = sum(dur for _, dur in events)
    if total < 30000:
        events.append((False, 30000 - total))
    return events


def render_pcm(
    events: list[tuple[bool, int]],
    carrier_hz: int,
    repeats: int = 6,
    stereo: bool = True,
) -> bytes:
    samples: list[int] = []
    phase = 0.0
    two_pi_f = 2.0 * math.pi * carrier_hz / SAMPLE_RATE

    def append_us(mark: bool, dur_us: int) -> None:
        nonlocal phase
        n = max(1, int(SAMPLE_RATE * dur_us / 1_000_000))
        for _ in range(n):
            if mark:
                # Hard square wave at full scale
                v = AMP if math.sin(phase) >= 0 else -AMP
                phase += two_pi_f
            else:
                v = 0
                phase = 0.0
            samples.append(v)

    gap_us = 25000
    for r in range(repeats):
        for mark, dur in events:
            append_us(mark, dur)
        if r + 1 < repeats:
            append_us(False, gap_us)
    append_us(False, 8000)

    if stereo:
        # Interleave L/R identical — drive tip and ring
        stereo_samples: list[int] = []
        for v in samples:
            stereo_samples.extend((v, v))
        return struct.pack("<" + "h" * len(stereo_samples), *stereo_samples)

    return struct.pack("<" + "h" * len(samples), *samples)


def write_wav(path: Path, pcm: bytes, channels: int = 2) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(pcm)


def main() -> int:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "/root/ir/xiaomi_power.wav")
    carrier = int(sys.argv[2]) if len(sys.argv) > 2 else 38000
    events = build_timeline_us()
    pcm = render_pcm(events, carrier_hz=carrier, repeats=6, stereo=True)
    write_wav(out, pcm, channels=2)
    print(
        f"Wrote {out} ({out.stat().st_size} bytes), "
        f"carrier={carrier} Hz stereo full-scale, POWER D=0x3C F=0xCC, repeats=6"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
