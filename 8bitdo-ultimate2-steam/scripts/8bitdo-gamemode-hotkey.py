#!/usr/bin/env python3
# 8BitDo Ultimate 2: Guide + LT + RT -> Game Mode (Desktop only).
# Blocking evdev read via select(); exits after successful switch.
from __future__ import annotations

import argparse
import configparser
import ctypes
import ctypes.util
import fcntl
import logging
import os
import select
import struct
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Set, Tuple

EV_KEY = 0x01
EV_ABS = 0x03

BTN_MODE = 0x0107
BTN_START = 0x007B
BTN_TL2 = 0x0108
BTN_TR2 = 0x0109

ABS_Z = 0x02
ABS_RZ = 0x03
ABS_BRAKE = 0x05
ABS_GAS = 0x09

EVENT_SIZE = 24
EVENT_FORMAT = "llHHi"

VENDOR = "2dc8"
PRODUCTS = {"6012", "310b"}
NAME_HINT = "ultimate 2"

DEFAULT_CONFIG_PATHS = (
    Path.home() / ".config/8bitdo/gamemode.conf",
    Path("/etc/8bitdo-gamemode.conf"),
)

GUIDE_CODES = (BTN_MODE, BTN_START)
LT_KEY_CODES = (BTN_TL2,)
RT_KEY_CODES = (BTN_TR2,)
LT_ABS_CODES = (ABS_Z, ABS_BRAKE)
RT_ABS_CODES = (ABS_RZ, ABS_GAS)

IOC_READ = 2


def _ioc(dir_: int, type_: str, nr: int, size: int) -> int:
    return (dir_ << 30) | (size << 16) | (ord(type_) << 8) | nr


EVIOCGNAME = _ioc(IOC_READ, "E", 0x06, 256)


def eviocgbit(ev: int, size: int) -> int:
    return _ioc(IOC_READ, "E", 0x20 + ev, size)


def load_config() -> dict:
    cfg = configparser.ConfigParser()
    defaults = {
        "trigger_threshold": "128",
        "hold_ms": "400",
        "switch_command": "/usr/bin/return-to-gamemode",
        "fallback_command": "/usr/bin/steamos-session-select",
    }
    for path in DEFAULT_CONFIG_PATHS:
        if path.is_file():
            cfg.read(path)
            break
    section = cfg["hotkey"] if cfg.has_section("hotkey") else {}
    return {
        "trigger_threshold": int(section.get("trigger_threshold", defaults["trigger_threshold"])),
        "hold_ms": int(section.get("hold_ms", defaults["hold_ms"])),
        "switch_command": section.get("switch_command", defaults["switch_command"]),
        "fallback_command": section.get("fallback_command", defaults["fallback_command"]),
    }


def parse_input_devices() -> List[dict]:
    devices: List[dict] = []
    current: dict = {}
    proc = Path("/proc/bus/input/devices")
    if not proc.is_file():
        return devices
    for line in proc.read_text(encoding="utf-8", errors="replace").splitlines():
        if not line:
            if current:
                devices.append(current)
                current = {}
            continue
        if line.startswith("I:"):
            parts = {}
            for token in line[2:].strip().split():
                if "=" in token:
                    k, v = token.split("=", 1)
                    parts[k] = v.lower()
            current["vendor"] = parts.get("Vendor", "")
            current["product"] = parts.get("Product", "")
        elif line.startswith("N:"):
            current["name"] = line[2:].strip().strip('"')
        elif line.startswith("H:"):
            handlers = line.split("=", 1)[1].split()
            current["events"] = [h for h in handlers if h.startswith("event")]
    if current:
        devices.append(current)
    return devices


def matches_ultimate2(dev: dict) -> bool:
    if dev.get("vendor") != VENDOR:
        return False
    if dev.get("product") not in PRODUCTS:
        return False
    name = dev.get("name", "").lower()
    return NAME_HINT in name


def get_event_nodes() -> List[Path]:
    nodes: List[Path] = []
    seen: Set[str] = set()
    for dev in parse_input_devices():
        if not matches_ultimate2(dev):
            continue
        for ev in dev.get("events", []):
            if ev in seen:
                continue
            seen.add(ev)
            path = Path("/dev/input") / ev
            if path.exists():
                nodes.append(path)
    return sorted(nodes)


def device_name(fd: int) -> str:
    buf = bytearray(256)
    fcntl.ioctl(fd, EVIOCGNAME, buf)
    return buf.split(b"\x00")[0].decode("utf-8", errors="replace")


def has_code(fd: int, ev_type: int, code: int) -> bool:
    import array

    length = 64 if ev_type == EV_KEY else 32
    buf = array.array("B", [0] * length)
    try:
        fcntl.ioctl(fd, eviocgbit(ev_type, len(buf)), buf)
    except OSError:
        return False
    if code >= len(buf) * 8:
        return False
    return bool(buf[code // 8] & (1 << (code % 8)))


@dataclass
class Bindings:
    guide_codes: Set[int] = field(default_factory=set)
    lt_keys: Set[int] = field(default_factory=set)
    rt_keys: Set[int] = field(default_factory=set)
    lt_axes: Set[int] = field(default_factory=set)
    rt_axes: Set[int] = field(default_factory=set)


def detect_bindings(fd: int) -> Bindings:
    b = Bindings()
    for code in GUIDE_CODES:
        if has_code(fd, EV_KEY, code):
            b.guide_codes.add(code)
    for code in LT_KEY_CODES:
        if has_code(fd, EV_KEY, code):
            b.lt_keys.add(code)
    for code in RT_KEY_CODES:
        if has_code(fd, EV_KEY, code):
            b.rt_keys.add(code)
    for code in LT_ABS_CODES:
        if has_code(fd, EV_ABS, code):
            b.lt_axes.add(code)
    for code in RT_ABS_CODES:
        if has_code(fd, EV_ABS, code):
            b.rt_axes.add(code)
    return b


@dataclass
class OpenDevice:
    path: Path
    fd: int
    name: str
    bindings: Bindings


def open_devices(nodes: Iterable[Path]) -> List[OpenDevice]:
    opened: List[OpenDevice] = []
    for path in nodes:
        try:
            fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
        except OSError as exc:
            if exc.errno == 13:
                logging.warning("cannot open %s: %s — run install-gamemode-hotkey-udev.sh", path, exc)
            else:
                logging.warning("cannot open %s: %s", path, exc)
            continue
        try:
            name = device_name(fd)
            bindings = detect_bindings(fd)
        except OSError as exc:
            logging.warning("cannot query %s: %s", path, exc)
            os.close(fd)
            continue
        if not bindings.guide_codes and not bindings.lt_keys and not bindings.lt_axes:
            logging.debug("skip %s (%s): no relevant controls", path, name)
            os.close(fd)
            continue
        opened.append(OpenDevice(path=path, fd=fd, name=name, bindings=bindings))
        logging.info("watching %s (%s)", path, name)
    return opened


def setup_inotify() -> int:
    libc = ctypes.CDLL(ctypes.util.find_library("c"), use_errno=True)
    fd = libc.inotify_init1(0x00000800)  # IN_NONBLOCK
    if fd < 0:
        err = ctypes.get_errno()
        raise OSError(err, os.strerror(err))
    watch_mask = 0x00000100 | 0x00000200  # IN_CREATE | IN_MOVED_TO
    if libc.inotify_add_watch(fd, b"/dev/input", watch_mask) < 0:
        err = ctypes.get_errno()
        os.close(fd)
        raise OSError(err, os.strerror(err))
    return fd


@dataclass
class ComboState:
    guide: bool = False
    lt: bool = False
    rt: bool = False
    hold_start: Optional[float] = None

    def all_pressed(self) -> bool:
        return self.guide and self.lt and self.rt

    def reset_hold(self) -> None:
        self.hold_start = None


class HotkeyDaemon:
    def __init__(self, config: dict) -> None:
        self.config = config
        self.threshold = config["trigger_threshold"]
        self.hold_ms = config["hold_ms"]
        self.devices: List[OpenDevice] = []
        self.inotify_fd: Optional[int] = None
        self.state = ComboState()
        self.rescan()

    def close_all(self) -> None:
        for dev in self.devices:
            os.close(dev.fd)
        self.devices.clear()
        if self.inotify_fd is not None:
            os.close(self.inotify_fd)
            self.inotify_fd = None

    def rescan(self) -> None:
        for dev in self.devices:
            os.close(dev.fd)
        self.devices.clear()
        nodes = get_event_nodes()
        self.devices = open_devices(nodes)
        if self.inotify_fd is None:
            try:
                self.inotify_fd = setup_inotify()
            except OSError as exc:
                logging.warning("inotify unavailable: %s", exc)
        self.state = ComboState()

    def apply_event(self, bindings: Bindings, ev_type: int, code: int, value: int) -> None:
        if ev_type == EV_KEY:
            if code in bindings.guide_codes:
                self.state.guide = value != 0
            elif code in bindings.lt_keys:
                self.state.lt = value != 0
            elif code in bindings.rt_keys:
                self.state.rt = value != 0
        elif ev_type == EV_ABS:
            pressed = value >= self.threshold
            if code in bindings.lt_axes:
                self.state.lt = pressed
            elif code in bindings.rt_axes:
                self.state.rt = pressed

        if self.state.all_pressed():
            if self.state.hold_start is None:
                self.state.hold_start = time.monotonic()
        else:
            self.state.reset_hold()

    def check_hold(self) -> bool:
        if not self.state.all_pressed() or self.state.hold_start is None:
            return False
        return (time.monotonic() - self.state.hold_start) * 1000 >= self.hold_ms

    def switch_to_gamemode(self) -> None:
        primary = self.config["switch_command"]
        fallback = self.config["fallback_command"]
        for cmd in (primary, fallback):
            if not cmd:
                continue
            path = Path(cmd)
            if not path.is_file():
                logging.warning("command missing: %s", cmd)
                continue
            logging.info("switching to Game Mode: %s", cmd)
            subprocess.Popen([cmd], start_new_session=True)
            return
        raise RuntimeError("no switch command found (return-to-gamemode / steamos-session-select)")

    def run(self) -> None:
        if not self.devices:
            logging.info("no 8BitDo Ultimate 2 event nodes yet; waiting for hotplug")

        while True:
            if self.check_hold():
                self.switch_to_gamemode()
                logging.info("combo triggered; exiting")
                return

            fds: Dict[int, OpenDevice] = {}
            rlist: List[int] = []
            for dev in self.devices:
                fds[dev.fd] = dev
                rlist.append(dev.fd)
            if self.inotify_fd is not None:
                rlist.append(self.inotify_fd)

            if not rlist:
                rlist = [self.inotify_fd] if self.inotify_fd is not None else []
                if not rlist:
                    time.sleep(2)
                    self.rescan()
                    continue

            try:
                readable, _, _ = select.select(rlist, [], [], 2.0)
            except OSError as exc:
                logging.warning("select failed: %s", exc)
                self.rescan()
                continue

            if not readable:
                if not self.devices:
                    self.rescan()
                continue

            for fd in readable:
                if self.inotify_fd is not None and fd == self.inotify_fd:
                    try:
                        os.read(fd, 4096)
                    except OSError:
                        pass
                    self.rescan()
                    continue

                dev = fds.get(fd)
                if dev is None:
                    continue
                while True:
                    try:
                        data = os.read(fd, EVENT_SIZE * 32)
                    except BlockingIOError:
                        break
                    except OSError as exc:
                        logging.warning("read %s failed: %s", dev.path, exc)
                        self.rescan()
                        break
                    if not data:
                        break
                    for offset in range(0, len(data), EVENT_SIZE):
                        chunk = data[offset : offset + EVENT_SIZE]
                        if len(chunk) < EVENT_SIZE:
                            break
                        _sec, _usec, ev_type, code, value = struct.unpack(EVENT_FORMAT, chunk)
                        self.apply_event(dev.bindings, ev_type, code, value)
                        if self.check_hold():
                            self.switch_to_gamemode()
                            logging.info("combo triggered; exiting")
                            return


PERM_HINT = (
    "Permission denied on /dev/input/event*. On Bazzite, group input alone is often not enough.\n"
    "  sudo ./scripts/install-gamemode-hotkey-udev.sh\n"
    "  ./scripts/8bitdo-gamemode-check-perms.sh\n"
    "Then replug the controller and: systemctl --user restart 8bitdo-gamemode-hotkey.service"
)


def format_mode(path: Path) -> str:
    try:
        mode = path.stat().st_mode & 0o777
        return oct(mode)
    except OSError:
        return "?"


def describe_devices() -> int:
    nodes = get_event_nodes()
    if not nodes:
        print("No 8BitDo Ultimate 2 event devices found.")
        print("Turn on the controller (XInput or D-Input) and retry.")
        return 1
    denied = False
    for path in nodes:
        print(f"{path} mode={format_mode(path)}")
        try:
            fd = os.open(path, os.O_RDONLY)
        except OSError as exc:
            denied = True
            print(f"  OPEN FAILED: {exc}")
            continue
        try:
            name = device_name(fd)
            bindings = detect_bindings(fd)
        finally:
            os.close(fd)
        print(f"  name: {name}")
        print(f"  guide: {sorted(bindings.guide_codes) or 'none'}")
        print(f"  lt keys: {sorted(bindings.lt_keys) or 'none'}")
        print(f"  rt keys: {sorted(bindings.rt_keys) or 'none'}")
        print(f"  lt axes: {sorted(bindings.lt_axes) or 'none'}")
        print(f"  rt axes: {sorted(bindings.rt_axes) or 'none'}")
    if denied:
        print("")
        print(PERM_HINT)
        return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="8BitDo Ultimate 2 -> Game Mode hotkey")
    parser.add_argument("--list-devices", action="store_true", help="show detected evdev nodes")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="8bitdo-gamemode: %(message)s",
    )

    if args.list_devices:
        return describe_devices()

    if subprocess.run(["pgrep", "-x", "gamescope"], capture_output=True).returncode == 0:
        logging.info("gamescope active; nothing to do")
        return 0

    config = load_config()
    daemon = HotkeyDaemon(config)
    try:
        daemon.run()
    finally:
        daemon.close_all()
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
