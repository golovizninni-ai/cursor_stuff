#!/usr/bin/env python3
"""Minimal SOC TV panel: remote, scripts, autofix, messages."""

from __future__ import annotations

import base64
import json
import os
import signal
import subprocess
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

try:
    import PAM as pam_mod
except ImportError:  # pragma: no cover
    pam_mod = None

ROOT = Path(__file__).resolve().parent
TV_ADB = os.environ.get("TV_ADB", "192.168.0.2:5555")
PORT = int(os.environ.get("TV_PANEL_PORT", "8787"))
AUTOFIX_FLAG = Path(os.environ.get("AUTOFIX_FLAG", "/root/tv_autofix.enabled"))
MSG_PID = Path("/tmp/tvmsg-panel.pid")
TV_ON = "/root/tv_on.sh"
TV_OFF = "/root/tv_off.sh"
TV_MESSAGE = "/root/tv_message.sh"
ALLOWED_USERS = {
    u.strip()
    for u in os.environ.get("TV_PANEL_USERS", "root,dietpi").split(",")
    if u.strip()
}
PAM_SERVICE = os.environ.get("TV_PANEL_PAM_SERVICE", "login")


def check_linux_user(username: str, password: str) -> bool:
    """Authenticate against system accounts via Debian python3-pam (import PAM)."""
    if username not in ALLOWED_USERS or password is None or pam_mod is None:
        return False

    def pam_conv(auth, query_list, _user_data):
        resp = []
        for _query, qtype in query_list:
            if qtype == pam_mod.PAM_PROMPT_ECHO_ON:
                resp.append((username, 0))
            elif qtype == pam_mod.PAM_PROMPT_ECHO_OFF:
                resp.append((password, 0))
            elif qtype in (pam_mod.PAM_ERROR_MSG, pam_mod.PAM_TEXT_INFO):
                resp.append(("", 0))
            else:
                return None
        return resp

    auth = pam_mod.pam()
    try:
        auth.start(PAM_SERVICE)
        auth.set_item(pam_mod.PAM_USER, username)
        auth.set_item(pam_mod.PAM_CONV, pam_conv)
        auth.authenticate()
        auth.acct_mgmt()
        return True
    except pam_mod.error:
        return False
    except Exception:
        return False


def adb(*args: str, timeout: float = 8) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["adb", "-s", TV_ADB, *args],
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )


def adb_online() -> bool:
    try:
        subprocess.run(
            ["adb", "connect", TV_ADB],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        out = subprocess.run(
            ["adb", "devices"],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        ).stdout
        return f"{TV_ADB}\tdevice" in out or f"{TV_ADB}    device" in out
    except (subprocess.TimeoutExpired, OSError):
        return False


def autofix_enabled() -> bool:
    return AUTOFIX_FLAG.is_file()


def set_autofix(enabled: bool) -> None:
    if enabled:
        AUTOFIX_FLAG.touch()
    elif AUTOFIX_FLAG.exists():
        AUTOFIX_FLAG.unlink()


def message_active() -> bool:
    if not MSG_PID.is_file():
        return False
    try:
        pid = int(MSG_PID.read_text().strip())
    except ValueError:
        return False
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def switch_hdmi3() -> None:
    adb("shell", "am", "start", "-a", "com.mitv.tvhome.atv.app.tv.INPUTSOURCE_POPUP")
    subprocess.run(["sleep", "1"], check=False)
    adb("shell", "input", "tap", "640", "410")


def stop_message() -> None:
    if MSG_PID.is_file():
        try:
            pid = int(MSG_PID.read_text().strip())
            os.kill(pid, signal.SIGTERM)
        except (ValueError, OSError, ProcessLookupError):
            pass
        try:
            MSG_PID.unlink()
        except OSError:
            pass
    subprocess.run(
        ["pkill", "-f", "tv_message.sh"],
        capture_output=True,
        check=False,
    )
    subprocess.run(
        ["pkill", "-f", "http.server 8765"],
        capture_output=True,
        check=False,
    )
    adb("shell", "am", "force-stop", "org.chromium.webview_shell")
    switch_hdmi3()


def start_message(title: str, text: str, seconds: int) -> None:
    stop_message()
    proc = subprocess.Popen(
        [TV_MESSAGE, title, text, str(seconds)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    MSG_PID.write_text(str(proc.pid))


def spawn(cmd: list[str]) -> None:
    subprocess.Popen(
        cmd,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )


def read_json(handler: BaseHTTPRequestHandler) -> dict:
    length = int(handler.headers.get("Content-Length") or 0)
    raw = handler.rfile.read(length) if length else b"{}"
    if not raw:
        return {}
    return json.loads(raw.decode("utf-8"))


def send_json(handler: BaseHTTPRequestHandler, data: dict, code: int = 200) -> None:
    body = json.dumps(data).encode("utf-8")
    handler.send_response(code)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Content-Length", str(len(body)))
    handler.send_header("Cache-Control", "no-store")
    handler.end_headers()
    handler.wfile.write(body)


def send_file(handler: BaseHTTPRequestHandler, path: Path, content_type: str) -> None:
    if not path.is_file():
        handler.send_error(404)
        return
    data = path.read_bytes()
    handler.send_response(200)
    handler.send_header("Content-Type", content_type)
    handler.send_header("Content-Length", str(len(data)))
    handler.send_header("Cache-Control", "no-store")
    handler.end_headers()
    handler.wfile.write(data)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        return

    def require_auth(self) -> bool:
        hdr = self.headers.get("Authorization", "")
        if not hdr.startswith("Basic "):
            self.send_auth_required()
            return False
        try:
            raw = base64.b64decode(hdr[6:].strip()).decode("utf-8")
            user, password = raw.split(":", 1)
        except (ValueError, UnicodeDecodeError, base64.binascii.Error):
            self.send_auth_required()
            return False
        if not check_linux_user(user, password):
            self.send_auth_required()
            return False
        return True

    def send_auth_required(self) -> None:
        body = b"Unauthorized"
        self.send_response(401)
        self.send_header("WWW-Authenticate", 'Basic realm="TV Panel"')
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if not self.require_auth():
            return
        path = urllib.parse.urlparse(self.path).path
        if path in ("/", "/index.html"):
            send_file(self, ROOT / "index.html", "text/html; charset=utf-8")
        elif path == "/message.html":
            send_file(self, ROOT / "message.html", "text/html; charset=utf-8")
        elif path == "/api/status":
            send_json(
                self,
                {
                    "adb": adb_online(),
                    "autofix": autofix_enabled(),
                    "message_active": message_active(),
                },
            )
        else:
            self.send_error(404)

    def do_POST(self) -> None:
        if not self.require_auth():
            return
        path = urllib.parse.urlparse(self.path).path
        try:
            data = read_json(self)
        except json.JSONDecodeError:
            send_json(self, {"ok": False, "error": "bad json"}, 400)
            return

        if path == "/api/key":
            code = data.get("code")
            if not isinstance(code, int):
                send_json(self, {"ok": False, "error": "code"}, 400)
                return
            adb("shell", "input", "keyevent", str(code))
            send_json(self, {"ok": True})
        elif path == "/api/tv_on":
            spawn([TV_ON])
            send_json(self, {"ok": True})
        elif path == "/api/tv_off":
            spawn([TV_OFF])
            send_json(self, {"ok": True})
        elif path == "/api/hdmi3":
            switch_hdmi3()
            send_json(self, {"ok": True})
        elif path == "/api/source":
            adb("shell", "am", "start", "-a", "com.mitv.tvhome.atv.app.tv.INPUTSOURCE_POPUP")
            send_json(self, {"ok": True})
        elif path == "/api/autofix":
            enabled = bool(data.get("enabled"))
            set_autofix(enabled)
            send_json(self, {"ok": True, "autofix": autofix_enabled()})
        elif path == "/api/message":
            title = str(data.get("title") or "")
            text = str(data.get("text") or "")
            try:
                seconds = int(data.get("seconds", 30))
            except (TypeError, ValueError):
                send_json(self, {"ok": False, "error": "seconds"}, 400)
                return
            if seconds < 0:
                send_json(self, {"ok": False, "error": "seconds"}, 400)
                return
            if not adb_online():
                send_json(self, {"ok": False, "error": "adb offline"}, 503)
                return
            start_message(title, text, seconds)
            send_json(self, {"ok": True})
        elif path == "/api/message/stop":
            stop_message()
            send_json(self, {"ok": True})
        else:
            self.send_error(404)


def main() -> None:
    if pam_mod is None:
        raise SystemExit("python3-pam required (apt install python3-pam, import PAM)")
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    server.serve_forever()


if __name__ == "__main__":
    main()
