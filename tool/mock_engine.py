"""A server that implements docs/API.md and holds nothing.

This is what a brand new account looks like from the client's side: the
routes all exist, they all answer, and every list is empty. Run it, point
the app at it, and the screens you get are the screens a first-time user
gets.
"""
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

USER = {"handle": "rae", "name": "Rae Okonkwo", "email": "rae@example.com"}

EMPTY = {
    "/v1/me": USER,
    "/v1/standings": [],
    "/v1/trophies": [],
    "/v1/vault": [],
    "/v1/ecovault": [],
    "/v1/notes": [],
    "/v1/agents/runs": [],
    "/v1/agents/jobs": [],
    "/v1/designs": [],
    "/v1/connections": [],
    "/v1/week": {"pool": 0, "payoutLine": "Nothing paid out yet."},
}


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body=None):
        raw = b"" if body is None else json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,PATCH,DELETE,OPTIONS")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        if raw:
            self.wfile.write(raw)

    def do_OPTIONS(self):
        self._send(204)

    def do_GET(self):
        path = self.path.split("?")[0]
        if path in EMPTY:
            return self._send(200, EMPTY[path])
        self._send(404, {"message": f"No route {path}."})

    def do_POST(self):
        path = self.path.split("?")[0]
        if path.startswith("/v1/ecovault/") and path.endswith("/save"):
            return self._send(200, {"id": path.split("/")[3], "saved": True})
        if path == "/v1/auth/sign-in":
            return self._send(200, {
                "accessToken": "access-1",
                "refreshToken": "refresh-1",
                "expiresIn": 3600,
                "user": USER,
            })
        if path == "/v1/auth/refresh":
            return self._send(200, {
                "accessToken": "access-2",
                "refreshToken": "refresh-2",
                "expiresIn": 3600,
                "user": USER,
            })
        if path == "/v1/auth/sign-out":
            return self._send(204)
        self._send(404, {"message": f"No route {path}."})

    def do_DELETE(self):
        path = self.path.split("?")[0]
        if path.startswith("/v1/ecovault/") and path.endswith("/save"):
            return self._send(200, {"id": path.split("/")[3], "saved": False})
        self._send(204)

    def log_message(self, *args):
        pass


ThreadingHTTPServer(("127.0.0.1", 8111), Handler).serve_forever()
