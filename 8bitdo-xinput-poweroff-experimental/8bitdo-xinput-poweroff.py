#!/usr/bin/env python3
"""Best-effort: send Xbox 360 wireless power-off packet to 8BitDo Ultimate 2 in XInput (2dc8:310b).

NOT VERIFIED on hardware. The kernel treats 310b as a wired Xbox 360 clone (XTYPE_XBOX360),
not a Microsoft wireless receiver. The 08 C0 packet may be ignored.

Do not install this as part of the default sleep/dock fix.
"""

from __future__ import annotations

import ctypes
import ctypes.util
import os
import sys
import time
from pathlib import Path

VID = 0x2DC8
PID = 0x310B
ALLOW_PATHS = (
    Path("/etc/8bitdo-allow-xinput"),
    Path.home() / ".config/8bitdo-allow-xinput",
)
STAMP = Path("/run/8bitdo-xinput-poweroff-stamp")
DEBOUNCE_SEC = 5

# Xbox 360 wireless receiver power-off (xpad xpad360w_poweroff_controller)
PKT_360W_OFF = bytes([0x00, 0x00, 0x08, 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
# Wired 360 LED off-ish
PKT_LED_OFF = bytes([0x01, 0x03, 0x00])


def log(msg: str) -> None:
    sys.stderr.write(f"8bitdo-xinput-poweroff: {msg}\n")
    try:
        import syslog

        syslog.syslog(syslog.LOG_INFO, msg)
    except Exception:
        pass


def allowed() -> bool:
    return any(p.exists() for p in ALLOW_PATHS)


def debounced() -> bool:
    now = time.time()
    if STAMP.exists():
        try:
            last = float(STAMP.read_text().strip() or "0")
        except OSError:
            last = 0
        if now - last < DEBOUNCE_SEC:
            return True
    try:
        STAMP.write_text(str(int(now)))
    except OSError:
        pass
    return False


def sysfs_unbind_xpad() -> list[str]:
    """Unbind xpad from 2dc8:310b interfaces. Returns names to rebind."""
    rebound: list[str] = []
    usb = Path("/sys/bus/usb/devices")
    unbind = Path("/sys/bus/usb/drivers/xpad/unbind")
    if not unbind.exists():
        return rebound
    for dev in usb.iterdir():
        vendor = dev / "idVendor"
        product = dev / "idProduct"
        if not vendor.exists():
            continue
        if vendor.read_text().strip().lower() != "2dc8":
            continue
        if product.read_text().strip().lower() != "310b":
            continue
        for iface in dev.glob(f"{dev.name}:*"):
            driver = iface / "driver"
            if not driver.exists():
                continue
            if driver.resolve().name != "xpad":
                continue
            name = iface.name
            try:
                unbind.write_text(name)
                rebound.append(name)
                log(f"unbound xpad from {name}")
            except OSError as exc:
                log(f"unbind {name} failed: {exc}")
    return rebound


def sysfs_rebind_xpad(names: list[str]) -> None:
    bind = Path("/sys/bus/usb/drivers/xpad/bind")
    if not bind.exists():
        return
    for name in names:
        if not Path(f"/sys/bus/usb/devices/{name}").exists():
            continue
        try:
            bind.write_text(name)
            log(f"rebound xpad {name}")
        except OSError as exc:
            log(f"rebind {name} failed: {exc}")


class Libusb:
    LIBUSB_SUCCESS = 0
    LIBUSB_ERROR_NOT_FOUND = -5
    LIBUSB_ERROR_BUSY = -6
    LIBUSB_TRANSFER_TYPE_INTERRUPT = 3
    LIBUSB_ENDPOINT_DIR_MASK = 0x80
    LIBUSB_ENDPOINT_OUT = 0x00

    def __init__(self) -> None:
        path = ctypes.util.find_library("usb-1.0") or "libusb-1.0.so.0"
        self.lib = ctypes.CDLL(path)
        self.ctx = ctypes.c_void_p()
        self._setup()
        rc = self.lib.libusb_init(ctypes.byref(self.ctx))
        if rc != 0:
            raise RuntimeError(f"libusb_init failed: {rc}")

    def _setup(self) -> None:
        lib = self.lib
        lib.libusb_init.argtypes = [ctypes.POINTER(ctypes.c_void_p)]
        lib.libusb_init.restype = ctypes.c_int
        lib.libusb_exit.argtypes = [ctypes.c_void_p]
        lib.libusb_open_device_with_vid_pid.argtypes = [
            ctypes.c_void_p,
            ctypes.c_uint16,
            ctypes.c_uint16,
        ]
        lib.libusb_open_device_with_vid_pid.restype = ctypes.c_void_p
        lib.libusb_close.argtypes = [ctypes.c_void_p]
        lib.libusb_kernel_driver_active.argtypes = [ctypes.c_void_p, ctypes.c_int]
        lib.libusb_kernel_driver_active.restype = ctypes.c_int
        lib.libusb_detach_kernel_driver.argtypes = [ctypes.c_void_p, ctypes.c_int]
        lib.libusb_detach_kernel_driver.restype = ctypes.c_int
        lib.libusb_claim_interface.argtypes = [ctypes.c_void_p, ctypes.c_int]
        lib.libusb_claim_interface.restype = ctypes.c_int
        lib.libusb_release_interface.argtypes = [ctypes.c_void_p, ctypes.c_int]
        lib.libusb_interrupt_transfer.argtypes = [
            ctypes.c_void_p,
            ctypes.c_ubyte,
            ctypes.POINTER(ctypes.c_ubyte),
            ctypes.c_int,
            ctypes.POINTER(ctypes.c_int),
            ctypes.c_uint,
        ]
        lib.libusb_interrupt_transfer.restype = ctypes.c_int
        lib.libusb_get_device.argtypes = [ctypes.c_void_p]
        lib.libusb_get_device.restype = ctypes.c_void_p
        lib.libusb_get_config_descriptor.argtypes = [
            ctypes.c_void_p,
            ctypes.c_uint8,
            ctypes.POINTER(ctypes.c_void_p),
        ]
        lib.libusb_get_config_descriptor.restype = ctypes.c_int
        lib.libusb_free_config_descriptor.argtypes = [ctypes.c_void_p]

    def close_ctx(self) -> None:
        self.lib.libusb_exit(self.ctx)


class EndpointDesc(ctypes.Structure):
    _fields_ = [
        ("bLength", ctypes.c_uint8),
        ("bDescriptorType", ctypes.c_uint8),
        ("bEndpointAddress", ctypes.c_uint8),
        ("bmAttributes", ctypes.c_uint8),
        ("wMaxPacketSize", ctypes.c_uint16),
        ("bInterval", ctypes.c_uint8),
        ("bRefresh", ctypes.c_uint8),
        ("bSynchAddress", ctypes.c_uint8),
        ("extra", ctypes.c_void_p),
        ("extra_length", ctypes.c_int),
    ]


class InterfaceDesc(ctypes.Structure):
    _fields_ = [
        ("bLength", ctypes.c_uint8),
        ("bDescriptorType", ctypes.c_uint8),
        ("bInterfaceNumber", ctypes.c_uint8),
        ("bAlternateSetting", ctypes.c_uint8),
        ("bNumEndpoints", ctypes.c_uint8),
        ("bInterfaceClass", ctypes.c_uint8),
        ("bInterfaceSubClass", ctypes.c_uint8),
        ("bInterfaceProtocol", ctypes.c_uint8),
        ("iInterface", ctypes.c_uint8),
        ("endpoint", ctypes.POINTER(EndpointDesc)),
        ("extra", ctypes.c_void_p),
        ("extra_length", ctypes.c_int),
    ]


class Interface(ctypes.Structure):
    _fields_ = [
        ("altsetting", ctypes.POINTER(InterfaceDesc)),
        ("num_altsetting", ctypes.c_int),
    ]


class ConfigDesc(ctypes.Structure):
    _fields_ = [
        ("bLength", ctypes.c_uint8),
        ("bDescriptorType", ctypes.c_uint8),
        ("wTotalLength", ctypes.c_uint16),
        ("bNumInterfaces", ctypes.c_uint8),
        ("bConfigurationValue", ctypes.c_uint8),
        ("iConfiguration", ctypes.c_uint8),
        ("bmAttributes", ctypes.c_uint8),
        ("MaxPower", ctypes.c_uint8),
        ("interface", ctypes.POINTER(Interface)),
        ("extra", ctypes.c_void_p),
        ("extra_length", ctypes.c_int),
    ]


def find_xinput_out(usb: Libusb, handle: ctypes.c_void_p) -> tuple[int, int] | None:
    """Return (interface_number, endpoint_address) for interrupt OUT on vendor XInput iface."""
    dev = usb.lib.libusb_get_device(handle)
    cfg_ptr = ctypes.c_void_p()
    rc = usb.lib.libusb_get_config_descriptor(dev, 0, ctypes.byref(cfg_ptr))
    if rc != 0 or not cfg_ptr:
        return None
    try:
        cfg = ctypes.cast(cfg_ptr, ctypes.POINTER(ConfigDesc)).contents
        for i in range(cfg.bNumInterfaces):
            iface = cfg.interface[i]
            alt = iface.altsetting[0]
            if not (alt.bInterfaceClass == 0xFF and alt.bInterfaceSubClass == 0x5D):
                continue
            for e in range(alt.bNumEndpoints):
                ep = alt.endpoint[e]
                is_int = (ep.bmAttributes & 0x03) == usb.LIBUSB_TRANSFER_TYPE_INTERRUPT
                is_out = (ep.bEndpointAddress & usb.LIBUSB_ENDPOINT_DIR_MASK) == 0
                if is_int and is_out:
                    return alt.bInterfaceNumber, int(ep.bEndpointAddress)
    finally:
        usb.lib.libusb_free_config_descriptor(cfg_ptr)
    return None


def send_packets(usb: Libusb, handle: ctypes.c_void_p, iface: int, ep: int) -> None:
    if usb.lib.libusb_kernel_driver_active(handle, iface) == 1:
        usb.lib.libusb_detach_kernel_driver(handle, iface)
    rc = usb.lib.libusb_claim_interface(handle, iface)
    if rc != 0:
        raise RuntimeError(f"claim_interface {iface} failed: {rc}")
    try:
        for pkt in (PKT_360W_OFF, PKT_LED_OFF):
            buf = (ctypes.c_ubyte * len(pkt)).from_buffer_copy(pkt)
            transferred = ctypes.c_int(0)
            rc = usb.lib.libusb_interrupt_transfer(
                handle, ep, buf, len(pkt), ctypes.byref(transferred), 1000
            )
            log(f"interrupt OUT ep=0x{ep:02x} len={len(pkt)} rc={rc} xfer={transferred.value}")
            time.sleep(0.2)
    finally:
        usb.lib.libusb_release_interface(handle, iface)


def device_still_xinput() -> bool:
    usb = Path("/sys/bus/usb/devices")
    for dev in usb.iterdir():
        vendor = dev / "idVendor"
        product = dev / "idProduct"
        if not vendor.exists():
            continue
        if vendor.read_text().strip().lower() != "2dc8":
            continue
        if product.read_text().strip().lower() == "310b":
            return True
    return False


def main() -> int:
    if os.geteuid() != 0:
        log("need root")
        return 1
    if allowed():
        log("allow-xinput present, skip")
        return 0
    if debounced():
        log("debounce, skip")
        return 0
    if not device_still_xinput():
        log("no 2dc8:310b")
        return 0

    rebound = sysfs_unbind_xpad()
    time.sleep(0.2)
    usb = Libusb()
    try:
        handle = usb.lib.libusb_open_device_with_vid_pid(usb.ctx, VID, PID)
        if not handle:
            log("libusb open 2dc8:310b failed (already gone?)")
            return 0
        try:
            found = find_xinput_out(usb, handle)
            if not found:
                log("no interrupt OUT on XInput interface")
                return 1
            iface, ep = found
            log(f"XInput iface={iface} ep=0x{ep:02x}")
            send_packets(usb, handle, iface, ep)
        finally:
            usb.lib.libusb_close(handle)
    finally:
        usb.close_ctx()

    time.sleep(1.5)
    if device_still_xinput():
        log("packet ignored, still 310b — hold Home 3s")
        sysfs_rebind_xpad(rebound)
        return 2
    log("310b gone — controller likely off")
    return 0


if __name__ == "__main__":
    sys.exit(main())
