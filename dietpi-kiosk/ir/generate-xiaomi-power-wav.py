#!/usr/bin/env python3
"""Generate Xiaomi TV KEY_POWER as a 38/36 kHz carrier WAV for 3.5mm IR blaster.

Protocol (JP1 / IRP, Xiaomi RC-MM variant):
  {36k,290,msb}<2,-2|2,-3|2,-4|2,-5>(1000u,-2,D:8,F:8,C:4,2,^30m)*
  C=(D[7:4]^D[3:0]^F[7:4]^F[3:0])
  POWER: D=0x3C, F=0xCC

Usage:
  generate-xiaomi-power-wav.py [/root/ir/xiaomi_power.wav]
"""

from __future__ import annotations

import math
import struct
import sys
import wave
from pathlib import Path

# IRP timing
CARRIER_HZ = 36000
UNIT_US = 290
SAMPLE_RATE = 192000  # high enough to carry 36 kHz
AMP = 29000  # int16 amplitude (leave headroom)


def checksum(d: int, f: int) -> int:
    return ((d >> 4) ^ (d & 0xF) ^ (f >> 4) ^ (f & 0xF)) & 0xF


def encode_bits_msb(value: int, nbits: int) -> list[int]:
    """Return list of 0/1 bits, MSB first."""
    bits = []
    for i in range(nbits - 1, -1, -1):
        bits.append((value >> i) & 1)
    return bits


def symbol_for_dibit(b1: int, b0: int) -> tuple[int, int]:
    """Map 2 bits to (mark_units, space_units) per IRP <2,-2|2,-3|2,-4|2,-5>."""
    idx = (b1 << 1) | b0
    # 00->2/-2, 01->2/-3, 10->2/-4, 11->2/-5
    return (2, -(2 + idx))


def build_timeline_us(d: int = 0x3C, f: int = 0xCC) -> list[tuple[bool, int]]:
    """List of (mark?, duration_us)."""
    c = checksum(d, f)
    events: list[tuple[bool, int]] = []

    # Header: 1000u mark, then -2 units space
    events.append((True, 1000))
    events.append((False, 2 * UNIT_US))

    bits = encode_bits_msb(d, 8) + encode_bits_msb(f, 8) + encode_bits_msb(c, 4)
    # pad to even for dibits
    if len(bits) % 2:
        bits.append(0)

    for i in range(0, len(bits), 2):
        mark_u, space_u = symbol_for_dibit(bits[i], bits[i + 1])
        events.append((True, mark_u * UNIT_US))
        events.append((False, abs(space_u) * UNIT_US))

    # Trailing mark: +2 units
    events.append((True, 2 * UNIT_US))

    # Pad frame to 30 ms total (^30m)
    total = sum(dur for _, dur in events)
    if total < 30000:
        events.append((False, 30000 - total))

    return events


def render_pcm(events: list[tuple[bool, int]], repeats: int = 2) -> bytes:
    samples: list[int] = []
    phase = 0.0
    two_pi_f = 2.0 * math.pi * CARRIER_HZ / SAMPLE_RATE

    def append_us(mark: bool, dur_us: int) -> None:
        nonlocal phase
        n = max(1, int(SAMPLE_RATE * dur_us / 1_000_000))
        for _ in range(n):
            if mark:
                # square-ish carrier via sign of sine
                v = AMP if math.sin(phase) >= 0 else -AMP
                phase += two_pi_f
            else:
                v = 0
                phase = 0.0
            samples.append(v)

    gap_us = 30000  # gap between repeats
    for r in range(repeats):
        for mark, dur in events:
            append_us(mark, dur)
        if r + 1 < repeats:
            append_us(False, gap_us)

    # short trailing silence
    append_us(False, 10000)
    return struct.pack("<" + "h" * len(samples), *samples)


def write_wav(path: Path, pcm: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(pcm)


def main() -> int:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "/root/ir/xiaomi_power.wav")
    events = build_timeline_us()
    pcm = render_pcm(events, repeats=3)
    write_wav(out, pcm)
    print(f"Wrote {out} ({out.stat().st_size} bytes), carrier={CARRIER_HZ} Hz, POWER D=0x3C F=0xCC")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
