#!/usr/bin/env python3
"""Toggle GAMESCOPE_DISPLAY_HDR_ENABLED on gamescope Xwayland (no xprop needed)."""
from __future__ import annotations

import ctypes
import ctypes.util
import os
import sys
import time


def _load_x11():
    path = ctypes.util.find_library("X11")
    if not path:
        raise RuntimeError("libX11 not found")
    x11 = ctypes.CDLL(path)
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
    x11.XDefaultRootWindow.restype = ctypes.c_ulong
    x11.XInternAtom.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
    x11.XInternAtom.restype = ctypes.c_ulong
    x11.XChangeProperty.argtypes = [
        ctypes.c_void_p,
        ctypes.c_ulong,
        ctypes.c_ulong,
        ctypes.c_ulong,
        ctypes.c_int,
        ctypes.c_int,
        ctypes.c_void_p,
        ctypes.c_int,
    ]
    x11.XChangeProperty.restype = ctypes.c_int
    x11.XFlush.argtypes = [ctypes.c_void_p]
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    x11.XGetWindowProperty.argtypes = [
        ctypes.c_void_p,
        ctypes.c_ulong,
        ctypes.c_ulong,
        ctypes.c_long,
        ctypes.c_long,
        ctypes.c_int,
        ctypes.c_ulong,
        ctypes.POINTER(ctypes.c_ulong),
        ctypes.POINTER(ctypes.c_int),
        ctypes.POINTER(ctypes.c_ulong),
        ctypes.POINTER(ctypes.c_ulong),
        ctypes.POINTER(ctypes.POINTER(ctypes.c_ubyte)),
    ]
    x11.XGetWindowProperty.restype = ctypes.c_int
    x11.XFree.argtypes = [ctypes.c_void_p]
    return x11


XA_CARDINAL = 6
PropModeReplace = 0


class Display:
    def __init__(self, display_name: str | None):
        self.x11 = _load_x11()
        name = display_name.encode() if display_name else None
        self.dpy = self.x11.XOpenDisplay(name)
        if not self.dpy:
            raise RuntimeError(f"cannot open display {display_name!r}")
        self.root = self.x11.XDefaultRootWindow(self.dpy)

    def close(self):
        if self.dpy:
            self.x11.XCloseDisplay(self.dpy)
            self.dpy = None

    def atom(self, name: str) -> int:
        return self.x11.XInternAtom(self.dpy, name.encode(), 0)

    def set_cardinal(self, atom_name: str, value: int) -> None:
        atom = self.atom(atom_name)
        buf = (ctypes.c_ulong * 1)(value)
        self.x11.XChangeProperty(
            self.dpy,
            self.root,
            atom,
            XA_CARDINAL,
            32,
            PropModeReplace,
            ctypes.cast(buf, ctypes.c_void_p),
            1,
        )
        self.x11.XFlush(self.dpy)

    def get_cardinal(self, atom_name: str) -> int | None:
        atom = self.atom(atom_name)
        actual_type = ctypes.c_ulong()
        actual_format = ctypes.c_int()
        nitems = ctypes.c_ulong()
        bytes_after = ctypes.c_ulong()
        prop = ctypes.POINTER(ctypes.c_ubyte)()
        status = self.x11.XGetWindowProperty(
            self.dpy,
            self.root,
            atom,
            0,
            1,
            0,
            XA_CARDINAL,
            ctypes.byref(actual_type),
            ctypes.byref(actual_format),
            ctypes.byref(nitems),
            ctypes.byref(bytes_after),
            ctypes.byref(prop),
        )
        if status != 0 or not prop or nitems.value < 1 or actual_format.value != 32:
            if prop:
                self.x11.XFree(prop)
            return None
        # 32-bit property: pointer to unsigned long
        val = ctypes.cast(prop, ctypes.POINTER(ctypes.c_ulong))[0]
        self.x11.XFree(prop)
        return int(val)


def find_displays() -> list[str]:
    found: list[str] = []
    env_d = os.environ.get("DISPLAY")
    if env_d:
        found.append(env_d)
    for d in (":1", ":0", ":2", ":3"):
        if d not in found:
            found.append(d)
    return found


def toggle_on_display(display: str, gap: float, passes: int) -> bool:
    try:
        dpy = Display(display)
    except Exception as e:
        print(f"skip {display}: {e}", file=sys.stderr)
        return False
    ok = False
    try:
        for p in range(1, passes + 1):
            before = dpy.get_cardinal("GAMESCOPE_DISPLAY_HDR_ENABLED")
            print(f"{display} pass {p}: before={before}", flush=True)
            dpy.set_cardinal("GAMESCOPE_DISPLAY_HDR_ENABLED", 0)
            time.sleep(gap)
            dpy.set_cardinal("GAMESCOPE_DISPLAY_HDR_ENABLED", 1)
            after = dpy.get_cardinal("GAMESCOPE_DISPLAY_HDR_ENABLED")
            print(f"{display} pass {p}: after={after}", flush=True)
            ok = True
            if p < passes:
                time.sleep(float(os.environ.get("HDR_NUDGE_SECOND_DELAY", "5")))
    finally:
        dpy.close()
    return ok


def main() -> int:
    gap = float(os.environ.get("HDR_TOGGLE_GAP", "2.0"))
    passes = int(os.environ.get("HDR_NUDGE_PASSES", "2"))
    only = os.environ.get("DISPLAY")
    displays = [only] if only else find_displays()
    any_ok = False
    for d in displays:
        if toggle_on_display(d, gap, passes):
            any_ok = True
            # достаточно одного рабочего display
            break
    return 0 if any_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
