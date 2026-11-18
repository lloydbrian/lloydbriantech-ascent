"""A deliberately configurable test target for run-live-checks.sh.

Listens on 127.0.0.1 only, on a free port it writes to PORTFILE, and serves one of
three behaviours:
  hardened    every check passes: headers set, TRACE refused, no traversal, no
              disclosure, writes need sign-in, 413 for big bodies, AI gated
  vulnerable  every check fails: no headers, a version banner, TRACE echoed, a
              passwd file through traversal, .env and .git served, writes accepted
              without sign-in, big bodies accepted, a stack trace for bad JSON, an
              AI endpoint that obeys the canary, no rate limit
  ratelimited hardened, but the AI endpoint answers without sign-in, refuses the
              canary and returns 429 after three requests
Usage: python3 live-app.py MODE PORTFILE
Used only by tests/plugins/ascent-security/test-run-live-checks.sh, which stops it;
it also stops itself after 300 seconds, so a test that dies never leaves it running.
"""
import os
import socketserver
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

MODE = sys.argv[1]
PORTFILE = sys.argv[2]
PASSWD = b"root:x:0:0:root:/root:/bin/sh\ndaemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin\n"
TRACE = b'Traceback (most recent call last):\n  File "/srv/app.py", line 9, in post\nValueError: bad json\n'
AI_CALLS = [0]


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "fixture"
    sys_version = ""

    def log_message(self, *args):
        pass

    def version_string(self):
        return "Express/4.18.2" if MODE == "vulnerable" else "fixture"

    def body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return self.rfile.read(n) if n else b""

    def send(self, status, data=b"", ctype="text/plain"):
        self.send_response(status)
        if MODE != "vulnerable":
            self.send_header("Content-Security-Policy", "default-src 'self'; frame-ancestors 'none'")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Referrer-Policy", "no-referrer")
            self.send_header("Permissions-Policy", "camera=()")
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        p = self.path
        if MODE == "vulnerable":
            if "passwd" in p:
                return self.send(200, PASSWD)
            if p == "/.env":
                return self.send(200, b"DATABASE_URL=postgres://app:hunter22@db/app\nAPI_KEY=sk_live_abcdef123456\n")
            if p == "/.git/config":
                return self.send(200, b"[core]\n\trepositoryformatversion = 0\n")
            if p == "/api/config":
                return self.send(200, b'{"database_url": "postgres://db/app", "debug": true}', "application/json")
        if p == "/" or p.startswith("/api/items/ascent-probe"):
            return self.send(200, b"<!doctype html><title>fixture</title>", "text/html")
        return self.send(404, b"not found")

    def do_TRACE(self):
        if MODE == "vulnerable":
            echo = ("TRACE %s HTTP/1.1\r\n" % self.path).encode() + str(self.headers).encode()
            return self.send(200, echo, "message/http")
        return self.send(405, b"method not allowed")

    def do_CONNECT(self):
        return self.send(200 if MODE == "vulnerable" else 405, b"")

    def write(self):
        data = self.body()
        if self.path.startswith("/api/chat"):
            return self.ai(data)
        if MODE == "vulnerable":
            if data.startswith(b'{"a":') and len(data) < 10:
                return self.send(500, TRACE)
            return self.send(200, b'{"ok": true}', "application/json")
        if len(data) > 1048576:
            return self.send(413, b"payload too large")
        return self.send(401, b"sign in")

    def ai(self, data):
        AI_CALLS[0] += 1
        if MODE == "vulnerable":
            if b"7 times 6" in data:
                return self.send(200, b'{"reply": "ASCENT 42"}', "application/json")
            return self.send(200, b'{"reply": "ok"}', "application/json")
        if MODE == "ratelimited":
            if AI_CALLS[0] > 3:
                return self.send(429, b"slow down")
            return self.send(200, b'{"reply": "I cannot do that."}', "application/json")
        return self.send(401, b"sign in")

    do_POST = write
    do_PUT = write
    do_PATCH = write
    do_DELETE = write


class Server(HTTPServer):
    # HTTPServer.server_bind looks up the host's name, which can take many
    # seconds on some CI machines; the fixture never needs the name.
    def server_bind(self):
        socketserver.TCPServer.server_bind(self)
        self.server_name, self.server_port = self.server_address[:2]


import threading
threading.Timer(300, lambda: os._exit(0)).start()
server = Server(("127.0.0.1", 0), Handler)
with open(PORTFILE + ".tmp", "w") as f:
    f.write(str(server.server_address[1]))
os.rename(PORTFILE + ".tmp", PORTFILE)
server.serve_forever()
