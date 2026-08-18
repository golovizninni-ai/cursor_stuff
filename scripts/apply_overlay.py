#!/usr/bin/env python3
"""Подставляет KEY = VALUE из overlay в .conf (раскомментирует существующие ключи)."""
from __future__ import annotations

import re
import sys
from pathlib import Path


def apply(target: Path, overlay: Path) -> None:
    text = target.read_text(encoding="utf-8", errors="replace")
    for raw in overlay.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key = line.split("=", 1)[0].strip()
        pattern = re.compile(
            rf"^[ \t]*#?[ \t]*{re.escape(key)}[ \t]*=.*$",
            re.MULTILINE,
        )
        if pattern.search(text):
            text = pattern.sub(line, text, count=1)
        else:
            if not text.endswith("\n"):
                text += "\n"
            text += f"\n{line}\n"
    target.write_text(text, encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: apply_overlay.py <target.conf> <overlay.conf>", file=sys.stderr)
        return 2
    target, overlay = Path(sys.argv[1]), Path(sys.argv[2])
    if not target.is_file():
        print(f"нет файла: {target}", file=sys.stderr)
        return 1
    if not overlay.is_file():
        print(f"нет overlay: {overlay}", file=sys.stderr)
        return 1
    apply(target, overlay)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
