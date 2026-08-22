#!/usr/bin/env python3
# 8BitDo Ultimate 2: Start + Select + LB + RB -> Game Mode (Desktop only).
# Blocking evdev read via select(); exits after successful switch.
# Note: Guide (BTN_MODE) often eaten by Steam — do not use in combo.
from __future__ import annotations

import argparse
import configparser
import ctypes
import ctypes.util
import fcntl
import logging
import os
import select
import shutil
import struct
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Set, Tuple


def shutil_which(cmd: str) -> Optional[str]:
    return shutil.which(cmd)

EV_KEY = 0x01
EV_ABS = 0x03
EV_SYN = 0x00

# linux/input-event-codes.h (gamepad)
BTN_TL = 0x136      # LB
BTN_TR = 0x137      # RB
BTN_SELECT = 0x13A  # − / Back / Select
BTN_START = 0x13B   # + / Start
BTN_MODE = 0x13C    # Guide/Home (not used — Steam often grabs)

EVENT_SIZE = 24
EVENT_FORMAT = "llHHi"

VENDOR = "2dc8"
PRODUCTS = {"6012", "310b"}
NAME_HINT = "ultimate 2"

DEFAULT_CONFIG_PATHS = (
    Path.home() / ".config/8bitdo/gamemode.conf",
    Path("/etc/8bitdo-gamemode.conf"),
)

# Combo: + (Start) + − (Select) + LB + RB
START_CODES = (BTN_START,)
SELECT_CODES = (BTN_SELECT,)
LB_CODES = (BTN_TL,)
RB_CODES = (BTN_TR,)

IOC_READ = 2


def _ioc(dir_: int, type_: str, nr: int, size: int) -> int:
    return (dir_ << 30) | (size << 16) | (ord(type_) << 8) | nr


EVIOCGNAME = _ioc(IOC_READ, "E", 0x06, 256)


def eviocgbit(ev: int, size: int) -> int:
    return _ioc(IOC_READ, "E", 0x20 + ev, size)


def load_config() -> dict:
    cfg = configparser.ConfigParser()
    defaults = {
        "hold_ms": "400",
        "switch_command": "/usr/local/bin/8bitdo-switch-gamemode",
        "fallback_command": "/usr/bin/return-to-gamemode",
    }
    for path in DEFAULT_CONFIG_PATHS:
        if path.is_file():
            cfg.read(path)
            break
    section = cfg["hotkey"] if cfg.has_section("hotkey") else {}
    return {
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
    start_codes: Set[int] = field(default_factory=set)
    select_codes: Set[int] = field(default_factory=set)
    lb_codes: Set[int] = field(default_factory=set)
    rb_codes: Set[int] = field(default_factory=set)

    def has_any(self) -> bool:
        return bool(self.start_codes or self.select_codes or self.lb_codes or self.rb_codes)


def detect_bindings(fd: int) -> Bindings:
    b = Bindings()
    for code in START_CODES:
        if has_code(fd, EV_KEY, code):
            b.start_codes.add(code)
    for code in SELECT_CODES:
        if has_code(fd, EV_KEY, code):
            b.select_codes.add(code)
    for code in LB_CODES:
        if has_code(fd, EV_KEY, code):
            b.lb_codes.add(code)
    for code in RB_CODES:
        if has_code(fd, EV_KEY, code):
            b.rb_codes.add(code)
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
        if not bindings.has_any():
            logging.debug("skip %s (%s): no Start/Select/LB/RB", path, name)
            os.close(fd)
            continue
        opened.append(OpenDevice(path=path, fd=fd, name=name, bindings=bindings))
        logging.info(
            "watching %s (%s) start=%s select=%s lb=%s rb=%s",
            path,
            name,
            sorted(bindings.start_codes),
            sorted(bindings.select_codes),
            sorted(bindings.lb_codes),
            sorted(bindings.rb_codes),
        )
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
    start: bool = False
    select: bool = False
    lb: bool = False
    rb: bool = False
    hold_start: Optional[float] = None

    def all_pressed(self) -> bool:
        return self.start and self.select and self.lb and self.rb

    def reset_hold(self) -> None:
        self.hold_start = None

    def summary(self) -> str:
        return (
            f"start={int(self.start)} select={int(self.select)} "
            f"lb={int(self.lb)} rb={int(self.rb)}"
        )


class HotkeyDaemon:
    def __init__(self, config: dict) -> None:
        self.config = config
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
        if ev_type != EV_KEY:
            return
        changed = False
        if code in bindings.start_codes:
            self.state.start = value != 0
            changed = True
        elif code in bindings.select_codes:
            self.state.select = value != 0
            changed = True
        elif code in bindings.lb_codes:
            self.state.lb = value != 0
            changed = True
        elif code in bindings.rb_codes:
            self.state.rb = value != 0
            changed = True
        if not changed:
            return

        logging.debug("combo state: %s", self.state.summary())
        if self.state.all_pressed():
            if self.state.hold_start is None:
                self.state.hold_start = time.monotonic()
                logging.info("combo armed (%s) — hold %dms", self.state.summary(), self.hold_ms)
        else:
            self.state.reset_hold()

    def check_hold(self) -> bool:
        if not self.state.all_pressed() or self.state.hold_start is None:
            return False
        return (time.monotonic() - self.state.hold_start) * 1000 >= self.hold_ms

    def switch_to_gamemode(self) -> None:
        # (cmd, args...) — Bazzite 44: steamosctl; 43: return-to-gamemode
        candidates: List[List[str]] = []
        primary = self.config["switch_command"]
        fallback = self.config["fallback_command"]
        if primary:
            candidates.append([primary])
        if fallback and fallback != primary:
            candidates.append([fallback])
        candidates.extend(
            [
                ["/usr/local/bin/8bitdo-switch-gamemode"],
                ["steamosctl", "switch-to-game-mode"],
                ["/usr/bin/return-to-gamemode"],
                ["/usr/bin/steamos-session-select", "gamescope"],
            ]
        )
        seen: Set[str] = set()
        for argv in candidates:
            key = " ".join(argv)
            if key in seen:
                continue
            seen.add(key)
            bin_path = argv[0]
            if "/" in bin_path:
                if not Path(bin_path).is_file():
                    continue
            elif not shutil_which(bin_path):
                continue
            logging.info("switching to Game Mode: %s", key)
            subprocess.Popen(argv, start_new_session=True)
            return
        raise RuntimeError(
            "no Game Mode switch found (install steamos-manager / compat/bazzite44)"
        )

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
    "Permission denied on /dev/input/event*.\n"
    "  sudo ./scripts/install-gamemode-hotkey-udev.sh\n"
    "  sudo /usr/local/bin/8bitdo-gamemode-chmod-evdev.sh\n"
    "  ./scripts/8bitdo-gamemode-check-perms.sh\n"
    "Expect mode 666 (crw-rw-rw-). Then: systemctl --user restart 8bitdo-gamemode-hotkey.service"
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
            has_mode = has_code(fd, EV_KEY, BTN_MODE)
        finally:
            os.close(fd)
        print(f"  name: {name}")
        print(f"  Start (+):  {sorted(bindings.start_codes) or 'MISSING'}")
        print(f"  Select (−): {sorted(bindings.select_codes) or 'MISSING'}")
        print(f"  LB:         {sorted(bindings.lb_codes) or 'MISSING'}")
        print(f"  RB:         {sorted(bindings.rb_codes) or 'MISSING'}")
        print(f"  Guide (unused): {'yes' if has_mode else 'no'} code={BTN_MODE}")
        print("  Combo: Start + Select + LB + RB (~0.4s)")
    if denied:
        print("")
        print(PERM_HINT)
        return 1
    return 0


BTN_NAMES = {
    BTN_TL: "LB",
    BTN_TR: "RB",
    BTN_SELECT: "Select(-)",
    BTN_START: "Start(+)",
    BTN_MODE: "Guide",
}


def monitor_devices() -> int:
    """Print EV_KEY for debugging mapping (Ctrl+C to stop)."""
    nodes = get_event_nodes()
    if not nodes:
        print("No devices. Turn on controller.")
        return 1
    fds: Dict[int, Path] = {}
    for path in nodes:
        try:
            fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
        except OSError as exc:
            print(f"open {path}: {exc}")
            continue
        fds[fd] = path
        print(f"listening {path}")
    if not fds:
        return 1
    print("Press Start / Select / LB / RB (and Guide to compare). Ctrl+C to exit.")
    try:
        while True:
            readable, _, _ = select.select(list(fds.keys()), [], [], 1.0)
            for fd in readable:
                try:
                    data = os.read(fd, EVENT_SIZE * 32)
                except BlockingIOError:
                    continue
                except OSError:
                    continue
                for offset in range(0, len(data), EVENT_SIZE):
                    chunk = data[offset : offset + EVENT_SIZE]
                    if len(chunk) < EVENT_SIZE:
                        break
                    _s, _u, ev_type, code, value = struct.unpack(EVENT_FORMAT, chunk)
                    if ev_type != EV_KEY:
                        continue
                    label = BTN_NAMES.get(code, f"code={code}")
                    print(f"{fds[fd].name}: {label} value={value}")
    except KeyboardInterrupt:
        print("")
    finally:
        for fd in fds:
            os.close(fd)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="8BitDo Ultimate 2 -> Game Mode hotkey")
    parser.add_argument("--list-devices", action="store_true", help="show detected evdev nodes")
    parser.add_argument("--monitor", action="store_true", help="print button presses (debug)")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="8bitdo-gamemode: %(message)s",
    )

    if args.list_devices:
        return describe_devices()
    if args.monitor:
        return monitor_devices()

    if subprocess.run(["pgrep", "-x", "gamescope"], capture_output=True).returncode == 0:
        logging.info("gamescope active; nothing to do")
        return 0
    # Bazzite 44: иногда gamescope живёт как gamescope-wl / session helper
    if subprocess.run(["pgrep", "-f", "gamescope-session"], capture_output=True).returncode == 0:
        if not os.environ.get("DESKTOP_SESSION", "").lower().startswith(("plasma", "gnome")):
            logging.info("gamescope-session active; nothing to do")
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
