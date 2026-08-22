#!/usr/bin/env python3
# 8BitDo Ultimate 2 hotkey → Game Mode (Desktop).
# Monitor: Start + Select + LB + RB  → OUTPUT_CONNECTOR=DP-1 + return-to-gamemode.service
# TV:      Start + Select + LT + RT  → OUTPUT_CONNECTOR=DP-3 + return-to-gamemode.service
# Blocking evdev; exits after successful switch.
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
from typing import Dict, Iterable, List, Optional, Set


def shutil_which(cmd: str) -> Optional[str]:
    return shutil.which(cmd)


EV_KEY = 0x01
EV_ABS = 0x03

# linux/input-event-codes.h
BTN_TL = 0x136  # LB
BTN_TR = 0x137  # RB
BTN_TL2 = 0x138  # LT digital (312)
BTN_TR2 = 0x139  # RT digital (313)
BTN_SELECT = 0x13A
BTN_START = 0x13B
BTN_MODE = 0x13C  # Guide — not used in combos

ABS_Z = 0x02   # LT axis (xpad)
ABS_RZ = 0x05  # RT axis (xpad)
ABS_GAS = 0x09
ABS_BRAKE = 0x0A

EVENT_SIZE = 24
EVENT_FORMAT = "llHHi"

VENDOR = "2dc8"
PRODUCTS = {"6012", "310b"}
NAME_HINT = "ultimate 2"

DEFAULT_CONFIG_PATHS = (
    Path.home() / ".config/8bitdo/gamemode.conf",
    Path("/etc/8bitdo-gamemode.conf"),
)

START_CODES = (BTN_START,)
SELECT_CODES = (BTN_SELECT,)
LB_CODES = (BTN_TL,)
RB_CODES = (BTN_TR,)
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


def expand_user(path: str) -> Path:
    return Path(os.path.expanduser(path))


def load_config() -> dict:
    cfg = configparser.ConfigParser()
    defaults = {
        "hold_ms": "400",
        "trigger_threshold": "128",
        "switch_command": "/usr/local/bin/8bitdo-switch-gamemode",
        "monitor_connector": "DP-1",
        "tv_connector": "DP-3",
    }
    for path in DEFAULT_CONFIG_PATHS:
        if path.is_file():
            cfg.read(path)
            break
    section = cfg["hotkey"] if cfg.has_section("hotkey") else {}
    return {
        "hold_ms": int(section.get("hold_ms", defaults["hold_ms"])),
        "trigger_threshold": int(section.get("trigger_threshold", defaults["trigger_threshold"])),
        "switch_command": section.get("switch_command", defaults["switch_command"]),
        "monitor_connector": section.get("monitor_connector", defaults["monitor_connector"]),
        "tv_connector": section.get("tv_connector", defaults["tv_connector"]),
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
    return NAME_HINT in dev.get("name", "").lower()


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
    lt_keys: Set[int] = field(default_factory=set)
    rt_keys: Set[int] = field(default_factory=set)
    lt_axes: Set[int] = field(default_factory=set)
    rt_axes: Set[int] = field(default_factory=set)

    def has_any(self) -> bool:
        return bool(
            self.start_codes
            or self.select_codes
            or self.lb_codes
            or self.rb_codes
            or self.lt_keys
            or self.rt_keys
            or self.lt_axes
            or self.rt_axes
        )


def detect_bindings(fd: int) -> Bindings:
    b = Bindings()
    for code, dest in (
        (START_CODES, "start_codes"),
        (SELECT_CODES, "select_codes"),
        (LB_CODES, "lb_codes"),
        (RB_CODES, "rb_codes"),
        (LT_KEY_CODES, "lt_keys"),
        (RT_KEY_CODES, "rt_keys"),
    ):
        for c in code:
            if has_code(fd, EV_KEY, c):
                getattr(b, dest).add(c)
    for code, dest in ((LT_ABS_CODES, "lt_axes"), (RT_ABS_CODES, "rt_axes")):
        for c in code:
            if has_code(fd, EV_ABS, c):
                getattr(b, dest).add(c)
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
            os.close(fd)
            continue
        opened.append(OpenDevice(path=path, fd=fd, name=name, bindings=bindings))
        logging.info("watching %s (%s)", path, name)
    return opened


def setup_inotify() -> int:
    libc = ctypes.CDLL(ctypes.util.find_library("c"), use_errno=True)
    fd = libc.inotify_init1(0x00000800)
    if fd < 0:
        err = ctypes.get_errno()
        raise OSError(err, os.strerror(err))
    if libc.inotify_add_watch(fd, b"/dev/input", 0x00000100 | 0x00000200) < 0:
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
    lt: bool = False
    rt: bool = False
    hold_start: Optional[float] = None
    armed: Optional[str] = None  # "monitor" | "tv"

    def monitor_ready(self) -> bool:
        return self.start and self.select and self.lb and self.rb

    def tv_ready(self) -> bool:
        return self.start and self.select and self.lt and self.rt

    def active_target(self) -> Optional[str]:
        # Prefer exact shoulder vs trigger combos; both rare simultaneously
        mon = self.monitor_ready()
        tv = self.tv_ready()
        if mon and not tv:
            return "monitor"
        if tv and not mon:
            return "tv"
        if mon and tv:
            # all six — prefer monitor (shoulders)
            return "monitor"
        return None

    def summary(self) -> str:
        return (
            f"start={int(self.start)} select={int(self.select)} "
            f"lb={int(self.lb)} rb={int(self.rb)} lt={int(self.lt)} rt={int(self.rt)}"
        )


class HotkeyDaemon:
    def __init__(self, config: dict) -> None:
        self.config = config
        self.hold_ms = config["hold_ms"]
        self.threshold = config["trigger_threshold"]
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
        self.devices = open_devices(get_event_nodes())
        if self.inotify_fd is None:
            try:
                self.inotify_fd = setup_inotify()
            except OSError as exc:
                logging.warning("inotify unavailable: %s", exc)
        self.state = ComboState()

    def apply_event(self, bindings: Bindings, ev_type: int, code: int, value: int) -> None:
        changed = False
        if ev_type == EV_KEY:
            pressed = value != 0
            if code in bindings.start_codes:
                self.state.start = pressed
                changed = True
            elif code in bindings.select_codes:
                self.state.select = pressed
                changed = True
            elif code in bindings.lb_codes:
                self.state.lb = pressed
                changed = True
            elif code in bindings.rb_codes:
                self.state.rb = pressed
                changed = True
            elif code in bindings.lt_keys:
                self.state.lt = pressed
                changed = True
            elif code in bindings.rt_keys:
                self.state.rt = pressed
                changed = True
        elif ev_type == EV_ABS:
            pressed = value >= self.threshold
            if code in bindings.lt_axes:
                self.state.lt = pressed
                changed = True
            elif code in bindings.rt_axes:
                self.state.rt = pressed
                changed = True
        if not changed:
            return

        target = self.state.active_target()
        logging.debug("state %s target=%s", self.state.summary(), target)
        if target:
            if self.state.armed != target:
                self.state.armed = target
                self.state.hold_start = time.monotonic()
                logging.info("combo armed → %s (%s), hold %dms", target, self.state.summary(), self.hold_ms)
        else:
            self.state.armed = None
            self.state.hold_start = None

    def check_hold(self) -> Optional[str]:
        if not self.state.armed or self.state.hold_start is None:
            return None
        if self.state.active_target() != self.state.armed:
            return None
        if (time.monotonic() - self.state.hold_start) * 1000 >= self.hold_ms:
            return self.state.armed
        return None

    def switch_to_gamemode(self, target: str) -> None:
        cmd = self.config["switch_command"]
        argv = [cmd, target]
        if Path(cmd).is_file() or shutil_which(cmd):
            logging.info("switching to Game Mode (%s): %s", target, " ".join(argv))
            subprocess.Popen(argv, start_new_session=True)
            return
        # Inline fallback matching user's .desktop files
        connector = (
            self.config["monitor_connector"] if target == "monitor" else self.config["tv_connector"]
        )
        env_file = expand_user("~/.config/environment.d/10-gamescope-session.conf")
        env_file.parent.mkdir(parents=True, exist_ok=True)
        env_file.write_text(f"OUTPUT_CONNECTOR={connector}\n", encoding="utf-8")
        logging.info("wrote %s OUTPUT_CONNECTOR=%s", env_file, connector)
        for args in (
            ["systemctl", "start", "return-to-gamemode.service"],
            ["systemctl", "--user", "start", "return-to-gamemode.service"],
            ["steamosctl", "switch-to-game-mode"],
            ["/usr/bin/return-to-gamemode"],
        ):
            bin0 = args[0]
            if "/" in bin0 and not Path(bin0).is_file():
                continue
            if "/" not in bin0 and not shutil_which(bin0):
                continue
            logging.info("fallback exec: %s", " ".join(args))
            subprocess.Popen(args, start_new_session=True)
            return
        raise RuntimeError("cannot start Game Mode (no return-to-gamemode.service / steamosctl)")

    def run(self) -> None:
        if not self.devices:
            logging.info("no 8BitDo Ultimate 2 event nodes yet; waiting for hotplug")

        while True:
            target = self.check_hold()
            if target:
                self.switch_to_gamemode(target)
                logging.info("combo triggered (%s); exiting", target)
                return

            fds: Dict[int, OpenDevice] = {d.fd: d for d in self.devices}
            rlist = list(fds.keys())
            if self.inotify_fd is not None:
                rlist.append(self.inotify_fd)

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
                if not dev:
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
                        _s, _u, ev_type, code, value = struct.unpack(EVENT_FORMAT, chunk)
                        self.apply_event(dev.bindings, ev_type, code, value)
                        target = self.check_hold()
                        if target:
                            self.switch_to_gamemode(target)
                            logging.info("combo triggered (%s); exiting", target)
                            return


PERM_HINT = (
    "Permission denied on /dev/input/event*.\n"
    "  sudo ./scripts/install-gamemode-hotkey-udev.sh\n"
    "  sudo /usr/local/bin/8bitdo-gamemode-chmod-evdev.sh"
)


def format_mode(path: Path) -> str:
    try:
        return oct(path.stat().st_mode & 0o777)
    except OSError:
        return "?"


def describe_devices() -> int:
    nodes = get_event_nodes()
    if not nodes:
        print("No 8BitDo Ultimate 2 event devices found.")
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
            b = detect_bindings(fd)
        finally:
            os.close(fd)
        print(f"  name: {name}")
        print(f"  Start:  {sorted(b.start_codes) or 'MISSING'}")
        print(f"  Select: {sorted(b.select_codes) or 'MISSING'}")
        print(f"  LB/RB:  {sorted(b.lb_codes)} / {sorted(b.rb_codes)}")
        print(f"  LT/RT keys: {sorted(b.lt_keys)} / {sorted(b.rt_keys)}")
        print(f"  LT/RT axes: {sorted(b.lt_axes)} / {sorted(b.rt_axes)}")
        print("  Monitor: Start+Select+LB+RB")
        print("  TV:      Start+Select+LT+RT")
    if denied:
        print(PERM_HINT)
        return 1
    return 0


BTN_NAMES = {
    BTN_TL: "LB",
    BTN_TR: "RB",
    BTN_TL2: "LT",
    BTN_TR2: "RT",
    BTN_SELECT: "Select(-)",
    BTN_START: "Start(+)",
    BTN_MODE: "Guide",
}


def monitor_devices() -> int:
    nodes = get_event_nodes()
    if not nodes:
        print("No devices.")
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
    print("Press buttons. Ctrl+C to exit.")
    try:
        while True:
            readable, _, _ = select.select(list(fds), [], [], 1.0)
            for fd in readable:
                try:
                    data = os.read(fd, EVENT_SIZE * 32)
                except (BlockingIOError, OSError):
                    continue
                for offset in range(0, len(data), EVENT_SIZE):
                    chunk = data[offset : offset + EVENT_SIZE]
                    if len(chunk) < EVENT_SIZE:
                        break
                    _s, _u, ev_type, code, value = struct.unpack(EVENT_FORMAT, chunk)
                    if ev_type == EV_KEY:
                        label = BTN_NAMES.get(code, f"key={code}")
                        print(f"{fds[fd].name}: {label} value={value}")
                    elif ev_type == EV_ABS and code in (ABS_Z, ABS_RZ, ABS_BRAKE, ABS_GAS):
                        print(f"{fds[fd].name}: axis={code} value={value}")
    except KeyboardInterrupt:
        print("")
    finally:
        for fd in fds:
            os.close(fd)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="8BitDo Ultimate 2 -> Game Mode hotkey")
    parser.add_argument("--list-devices", action="store_true")
    parser.add_argument("--monitor", action="store_true")
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
