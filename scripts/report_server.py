"""Serves /health (open, for Render and cron-job.org) and /report (requires X-Secret-Key).
/report returns the login result, the memory log tail and the login output tail."""
import hmac
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SECRET = os.environ.get("SECRET_KEY", "")
PORT = int(os.environ.get("PORT", "8080"))
SPIKE = "/tmp/spike"


def read_text(name: str) -> str:
    try:
        with open(os.path.join(SPIKE, name)) as f:
            return f.read()
    except FileNotFoundError:
        return ""


class Handler(BaseHTTPRequestHandler):
    def _send(self, code: int, body: dict) -> None:
        data = json.dumps(body, indent=2).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path.startswith("/health"):
            return self._send(200, {"ok": True})
        if self.path.startswith("/report"):
            key = self.headers.get("X-Secret-Key", "")
            if not SECRET or not hmac.compare_digest(key, SECRET):
                return self._send(401, {"error": "unauthorized"})
            login_raw = read_text("login.json")
            login = json.loads(login_raw) if login_raw else {"status": "login check not finished"}
            return self._send(200, {
                "login": login,
                "memory_log_tail": read_text("mem.log").splitlines()[-20:],
                "windows_tail": read_text("windows.txt").splitlines()[-30:],
                "login_output_tail": read_text("login.out").splitlines()[-30:],
            })
        return self._send(404, {"error": "not found"})

    def log_message(self, fmt, *args):  # keep Render logs quiet
        pass


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
