#!/usr/bin/env python3
"""Minimal SOC TV panel: remote, scripts, autofix, messages (PWA + HTTPS)."""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import secrets
import signal
import ssl
import subprocess
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

try:
    import PAM as pam_mod
except ImportError:  # pragma: no cover
    pam_mod = None

ROOT = Path(__file__).resolve().parent
TV_ADB = os.environ.get("TV_ADB", "192.168.0.2:5555")
PORT = int(os.environ.get("TV_PANEL_PORT", "443"))
AUTOFIX_FLAG = Path(os.environ.get("AUTOFIX_FLAG", "/root/tv_autofix.enabled"))
MSG_PID = Path("/tmp/tvmsg-panel.pid")
TV_ON = "/root/tv_on.sh"
TV_OFF = "/root/tv_off.sh"
TV_MESSAGE = "/root/tv_message.sh"
CERT_FILE = Path(os.environ.get("TV_PANEL_CERT", "/etc/tv-panel/cert.pem"))
KEY_FILE = Path(os.environ.get("TV_PANEL_KEY", "/etc/tv-panel/key.pem"))
DASHBOARDS_CFG = Path(os.environ.get("KIOSK_DASHBOARDS", "/etc/kiosk/dashboards.json"))
REFRESH_SCRIPT = "/usr/local/sbin/refresh-dashboards.sh"
REFRESH_LOCK = Path("/run/kiosk-refresh-cycle.lock")
X_ENV = {
    "DISPLAY": os.environ.get("DISPLAY", ":0"),
    "XAUTHORITY": os.environ.get("XAUTHORITY", "/home/dietpi/.Xauthority"),
    "PATH": "/usr/sbin:/usr/bin:/bin",
}
DEFAULT_DASHBOARDS = {
    "urls": [
        "https://alfa-soc.vls.lan/?orgId=1&from=now-24h&to=now&timezone=Europe%2FMoscow&var-tab=all&refresh=1m&kiosk/",
        "https://alfa-soc.vls.lan/d/mp-overview/maxpatrol-e28094-obzor?orgId=1&from=now-24h&to=now&timezone=Europe%2FMoscow&refresh=1m&kiosk",
        "https://zabbix-ib.vls.lan/",
    ],
    "rotate_enabled": True,
    "rotate_sec": 45,
}
ALLOWED_USERS = {
    u.strip()
    for u in os.environ.get("TV_PANEL_USERS", "pult").split(",")
    if u.strip()
}
PAM_SERVICE = os.environ.get("TV_PANEL_PAM_SERVICE", "tv-panel")
SESSION_COOKIE = "tv_panel_sess"
SESSION_MAX_AGE = int(os.environ.get("TV_PANEL_SESSION_MAX_AGE", str(90 * 24 * 3600)))
SESSION_SECRET_FILE = Path(
    os.environ.get("TV_PANEL_SESSION_SECRET_FILE", "/etc/tv-panel/session.secret")
)

# Public paths for PWA install (Chrome needs SW/manifest without Basic challenge loops)
PUBLIC_PATHS = {
    "/manifest.webmanifest",
    "/sw.js",
    "/icons/icon-192.png",
    "/icons/icon-512.png",
}

LOGIN_HTML = """<!DOCTYPE html>
<html lang="ru"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="theme-color" content="#12151a">
<title>TV пульт — вход</title>
<style>
body{margin:0;min-height:100vh;background:#12151a;color:#e8eef5;font-family:"Segoe UI",system-ui,sans-serif;
display:flex;align-items:center;justify-content:center;padding:1rem}
form{width:min(300px,100%);background:#1a1f27;border-radius:10px;padding:1rem}
h1{margin:0 0 .75rem;font-size:.95rem;font-weight:600;color:#8b97a8}
label{display:block;font-size:.75rem;color:#8b97a8;margin:.45rem 0 .2rem}
input{width:100%;box-sizing:border-box;border:0;border-radius:6px;background:#2a3140;color:#e8eef5;
padding:.55rem .5rem;font-size:1rem}
button{width:100%;margin-top:.85rem;border:0;border-radius:6px;background:#243548;color:#cfe6f8;
padding:.55rem;font-size:.9rem;cursor:pointer}
.err{color:#f0c0c0;font-size:.75rem;margin:0 0 .5rem;min-height:1em}
</style></head><body>
<form method="post" action="/login" autocomplete="username">
<h1>Вход в TV пульт</h1>
<p class="err">__ERR__</p>
<label for="u">Логин</label>
<input id="u" name="username" required autocomplete="username" autocapitalize="off" autocorrect="off">
<label for="p">Пароль</label>
<input id="p" name="password" type="password" required autocomplete="current-password">
<button type="submit">Войти</button>
</form></body></html>
"""


def _session_secret() -> bytes:
    env = os.environ.get("TV_PANEL_SESSION_SECRET")
    if env:
        return env.encode("utf-8")
    try:
        if SESSION_SECRET_FILE.is_file():
            return SESSION_SECRET_FILE.read_bytes().strip()
        SESSION_SECRET_FILE.parent.mkdir(parents=True, exist_ok=True)
        secret = secrets.token_hex(32).encode("ascii")
        SESSION_SECRET_FILE.write_bytes(secret)
        os.chmod(SESSION_SECRET_FILE, 0o600)
        return secret
    except Exception:
        return b"tv-panel-dev-secret-change-me"


def make_session_token(user: str) -> str:
    exp = int(time.time()) + SESSION_MAX_AGE
    payload = f"{user}:{exp}"
    sig = hmac.new(_session_secret(), payload.encode("utf-8"), hashlib.sha256).hexdigest()
    raw = f"{payload}:{sig}".encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def parse_session_token(token: str) -> str | None:
    try:
        pad = "=" * (-len(token) % 4)
        raw = base64.urlsafe_b64decode(token + pad).decode("utf-8")
        user, exp_s, sig = raw.rsplit(":", 2)
        if int(exp_s) < int(time.time()):
            return None
        payload = f"{user}:{exp_s}"
        expect = hmac.new(_session_secret(), payload.encode("utf-8"), hashlib.sha256).hexdigest()
        if not hmac.compare_digest(sig, expect):
            return None
        if user not in ALLOWED_USERS:
            return None
        return user
    except Exception:
        return None


def cookie_header_value(user: str) -> str:
    token = make_session_token(user)
    return (
        f"{SESSION_COOKIE}={token}; Path=/; Max-Age={SESSION_MAX_AGE}; "
        f"HttpOnly; Secure; SameSite=Lax"
    )


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


def xdotool_key(*keys: str) -> bool:
    env = {**os.environ, **X_ENV}
    try:
        r = subprocess.run(
            ["xdotool", "key", "--clearmodifiers", *keys],
            capture_output=True,
            text=True,
            timeout=8,
            check=False,
            env=env,
        )
        return r.returncode == 0
    except (subprocess.TimeoutExpired, OSError):
        return False


def load_dashboards() -> dict:
    if not DASHBOARDS_CFG.is_file():
        return dict(DEFAULT_DASHBOARDS)
    try:
        data = json.loads(DASHBOARDS_CFG.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return dict(DEFAULT_DASHBOARDS)
    urls = data.get("urls") if isinstance(data, dict) else None
    if not isinstance(urls, list):
        urls = list(DEFAULT_DASHBOARDS["urls"])
    urls = [u.strip() for u in urls if isinstance(u, str) and u.strip()]
    if not urls:
        urls = list(DEFAULT_DASHBOARDS["urls"])
    try:
        rotate_sec = int(data.get("rotate_sec", 45))
    except (TypeError, ValueError):
        rotate_sec = 45
    if rotate_sec < 5:
        rotate_sec = 5
    return {
        "urls": urls,
        "rotate_enabled": bool(data.get("rotate_enabled", True)),
        "rotate_sec": rotate_sec,
    }


def validate_dashboards(data: dict) -> tuple[dict | None, str | None]:
    urls_raw = data.get("urls")
    if not isinstance(urls_raw, list) or not urls_raw:
        return None, "urls"
    urls: list[str] = []
    for u in urls_raw:
        if not isinstance(u, str):
            return None, "urls"
        s = u.strip()
        if not s.startswith(("http://", "https://")):
            return None, "urls"
        urls.append(s)
    try:
        rotate_sec = int(data.get("rotate_sec", 45))
    except (TypeError, ValueError):
        return None, "rotate_sec"
    if rotate_sec < 5:
        return None, "rotate_sec"
    return {
        "urls": urls,
        "rotate_enabled": bool(data.get("rotate_enabled", True)),
        "rotate_sec": rotate_sec,
    }, None


def save_dashboards(cfg: dict) -> None:
    DASHBOARDS_CFG.parent.mkdir(parents=True, exist_ok=True)
    tmp = DASHBOARDS_CFG.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(cfg, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    tmp.replace(DASHBOARDS_CFG)


def restart_chromium() -> None:
    # DietPi: wrapper is /usr/bin/chromium, live process is /usr/lib/chromium/chromium.
    # Anchor patterns so we do not kill unrelated shells that mention the path in argv.
    subprocess.run(
        ["killall", "-TERM", "chromium"],
        capture_output=True,
        check=False,
    )
    subprocess.run(
        ["pkill", "-TERM", "-f", r"^/usr/lib/chromium/chromium( |$)"],
        capture_output=True,
        check=False,
    )
    subprocess.run(
        ["pkill", "-TERM", "-f", r"^/usr/bin/chromium( |$)"],
        capture_output=True,
        check=False,
    )


def start_refresh_cycle() -> bool:
    """Run refresh-dashboards.sh once; skip if already running."""
    REFRESH_LOCK.parent.mkdir(parents=True, exist_ok=True)
    script = f"""
set -e
exec 9>"{REFRESH_LOCK}"
flock -n 9 || exit 99
{REFRESH_SCRIPT}
"""
    try:
        proc = subprocess.Popen(
            ["/bin/bash", "-c", script],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
            env={**os.environ, **X_ENV},
        )
    except OSError:
        return False
    # If flock failed immediately, process exits 99 quickly — best-effort
    try:
        code = proc.wait(timeout=0.3)
        return code != 99
    except subprocess.TimeoutExpired:
        return True


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
    cookie = getattr(handler, "_pending_set_cookie", None)
    if cookie:
        handler.send_header("Set-Cookie", cookie)
        handler._pending_set_cookie = None
    handler.end_headers()
    handler.wfile.write(body)


def send_file(
    handler: BaseHTTPRequestHandler,
    path: Path,
    content_type: str,
    cache: str = "no-store",
) -> None:
    if not path.is_file():
        handler.send_error(404)
        return
    data = path.read_bytes()
    handler.send_response(200)
    handler.send_header("Content-Type", content_type)
    handler.send_header("Content-Length", str(len(data)))
    handler.send_header("Cache-Control", cache)
    cookie = getattr(handler, "_pending_set_cookie", None)
    if cookie:
        handler.send_header("Set-Cookie", cookie)
        handler._pending_set_cookie = None
    handler.end_headers()
    handler.wfile.write(data)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        return

    def _cookies(self) -> dict[str, str]:
        out: dict[str, str] = {}
        raw = self.headers.get("Cookie") or ""
        for part in raw.split(";"):
            if "=" not in part:
                continue
            k, v = part.split("=", 1)
            out[k.strip()] = v.strip()
        return out

    def _wants_html_login(self) -> bool:
        path = urllib.parse.urlparse(self.path).path
        if path.startswith("/api/"):
            return False
        dest = self.headers.get("Sec-Fetch-Dest", "")
        if dest in ("document", "iframe", ""):
            # empty dest: older clients / some PWA navigations
            if dest == "document" or dest == "iframe":
                return True
            accept = self.headers.get("Accept", "")
            if not accept or "text/html" in accept:
                return True
        accept = self.headers.get("Accept", "")
        return "text/html" in accept

    def _issue_session(self, user: str) -> None:
        self._pending_set_cookie = cookie_header_value(user)

    def require_auth(self) -> bool:
        sess_user = parse_session_token(self._cookies().get(SESSION_COOKIE, ""))
        if sess_user:
            self._issue_session(sess_user)
            return True
        self.send_auth_required()
        return False

    def send_auth_required(self) -> None:
        # No WWW-Authenticate — only web form / JSON (avoids browser Basic dialog)
        if self._wants_html_login():
            body = LOGIN_HTML.replace("__ERR__", "").encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)
            return
        body = b'{"ok":false,"error":"unauthorized"}'
        self.send_response(401)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def handle_login(self) -> None:
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b""
        ctype = (self.headers.get("Content-Type") or "").split(";")[0].strip()
        user = ""
        password = ""
        if ctype == "application/json":
            try:
                data = json.loads(raw.decode("utf-8") or "{}")
            except json.JSONDecodeError:
                data = {}
            user = str(data.get("username") or "")
            password = str(data.get("password") or "")
        else:
            form = urllib.parse.parse_qs(raw.decode("utf-8", errors="replace"))
            user = (form.get("username") or [""])[0]
            password = (form.get("password") or [""])[0]
        if not check_linux_user(user, password):
            body = LOGIN_HTML.replace("__ERR__", "Неверный логин или пароль").encode("utf-8")
            self.send_response(401)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)
            return
        self.send_response(303)
        self.send_header("Set-Cookie", cookie_header_value(user))
        self.send_header("Location", "/")
        self.send_header("Content-Length", "0")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()

    def do_GET(self) -> None:
        path = urllib.parse.urlparse(self.path).path
        if path in PUBLIC_PATHS:
            self.serve_public(path)
            return
        if not self.require_auth():
            return
        if path in ("/", "/index.html"):
            send_file(self, ROOT / "index.html", "text/html; charset=utf-8")
        elif path == "/message.html":
            send_file(self, ROOT / "message.html", "text/html; charset=utf-8")
        elif path == "/dashboards.html":
            send_file(self, ROOT / "dashboards.html", "text/html; charset=utf-8")
        elif path == "/api/status":
            send_json(
                self,
                {
                    "adb": adb_online(),
                    "autofix": autofix_enabled(),
                    "message_active": message_active(),
                },
            )
        elif path == "/api/dashboards":
            send_json(self, load_dashboards())
        else:
            self.send_error(404)

    def serve_public(self, path: str) -> None:
        if path == "/manifest.webmanifest":
            send_file(
                self,
                ROOT / "manifest.webmanifest",
                "application/manifest+json",
                cache="public, max-age=300",
            )
        elif path == "/sw.js":
            send_file(
                self,
                ROOT / "sw.js",
                "application/javascript; charset=utf-8",
                cache="no-cache",
            )
        elif path == "/icons/icon-192.png":
            send_file(self, ROOT / "icons" / "icon-192.png", "image/png", cache="public, max-age=86400")
        elif path == "/icons/icon-512.png":
            send_file(self, ROOT / "icons" / "icon-512.png", "image/png", cache="public, max-age=86400")
        else:
            self.send_error(404)

    def do_POST(self) -> None:
        path = urllib.parse.urlparse(self.path).path
        if path == "/login":
            self.handle_login()
            return
        if not self.require_auth():
            return
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
        elif path == "/api/dashboards":
            cfg, err = validate_dashboards(data)
            if cfg is None:
                send_json(self, {"ok": False, "error": err or "invalid"}, 400)
                return
            old = load_dashboards()
            save_dashboards(cfg)
            restarted = old.get("urls") != cfg.get("urls")
            if restarted:
                restart_chromium()
            send_json(self, {"ok": True, "restarted": restarted, **cfg})
        elif path == "/api/dashboards/prev":
            send_json(self, {"ok": xdotool_key("ctrl+Page_Up")})
        elif path == "/api/dashboards/next":
            send_json(self, {"ok": xdotool_key("ctrl+Page_Down")})
        elif path == "/api/dashboards/refresh":
            send_json(self, {"ok": xdotool_key("F5")})
        elif path == "/api/dashboards/refresh-cycle":
            ok = start_refresh_cycle()
            send_json(
                self,
                {"ok": ok, **({} if ok else {"error": "busy"})},
                200 if ok else 409,
            )
        elif path == "/api/dashboards/restart":
            restart_chromium()
            send_json(self, {"ok": True})
        else:
            self.send_error(404)


def main() -> None:
    if pam_mod is None:
        raise SystemExit("python3-pam required (apt install python3-pam, import PAM)")
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    if CERT_FILE.is_file() and KEY_FILE.is_file():
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain(str(CERT_FILE), str(KEY_FILE))
        server.socket = ctx.wrap_socket(server.socket, server_side=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
