"""A server that implements docs/API.md and holds nothing.

This is what a brand new account looks like from the client's side: the
routes all exist, they all answer, and every list is empty. Run it, point
the app at it, and the screens you get are the screens a first-time user
gets.
"""
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

USER = {"handle": "rae", "name": "Rae Okonkwo", "email": "rae@example.com"}
AVATARS = []
_next_id = [1]
# None until PATCH /v1/me/location sets it. A brand new account has shared
# no location, so GET /v1/league must answer "not placed yet" until then —
# never the global board in a league's clothing.
LOCATION = {"set": False}


def league_placement():
    return {
        "division": "bronze",
        "regionLabel": "Local area",
        "promoteCount": 1,
        "relegateCount": 0,
        "rows": [
            {"rank": 1, "name": USER["name"], "earnings": 0, "movement": 0,
             "isYou": True},
        ],
    }

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
    # Same list object POST/DELETE below mutate, so a GET always sees
    # whatever this run has been asked to create.
    "/v1/avatars": AVATARS,
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
        if path == "/v1/league":
            return self._send(200, league_placement() if LOCATION["set"] else {})
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
        if path == "/v1/uploads":
            length = int(self.headers.get("Content-Length", 0))
            self.rfile.read(length)  # discarded — nothing here stores files
            n = _next_id[0]
            _next_id[0] += 1
            return self._send(200, {"id": f"u{n}"})
        if path == "/v1/avatars":
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length) or b"{}")
            avatar = {
                "id": f"avatar-{len(AVATARS) + 1}",
                "name": body.get("name") or "Avatar",
                "status": "training",
                "personal": False,
            }
            AVATARS.append(avatar)
            return self._send(200, avatar)
        if path.startswith("/v1/avatars/") and path.endswith("/personal"):
            avatar_id = path.split("/")[3]
            made_personal = None
            for avatar in AVATARS:
                avatar["personal"] = avatar["id"] == avatar_id
                if avatar["personal"]:
                    made_personal = avatar
            if made_personal is None:
                return self._send(404, {"message": f"No avatar {avatar_id}."})
            return self._send(200, made_personal)
        self._send(404, {"message": f"No route {path}."})

    def do_PATCH(self):
        path = self.path.split("?")[0]
        if path == "/v1/me":
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length) or b"{}")
            USER.update({k: v for k, v in body.items() if k in USER})
            return self._send(200, USER)
        if path == "/v1/me/location":
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length) or b"{}")
            if "lat" not in body or "lng" not in body:
                return self._send(400, {"message": "lat and lng are required."})
            LOCATION["set"] = True
            return self._send(200, league_placement())
        self._send(404, {"message": f"No route {path}."})

    def do_DELETE(self):
        path = self.path.split("?")[0]
        if path.startswith("/v1/ecovault/") and path.endswith("/save"):
            return self._send(200, {"id": path.split("/")[3], "saved": False})
        if path.startswith("/v1/avatars/"):
            avatar_id = path.split("/")[3]
            AVATARS[:] = [a for a in AVATARS if a["id"] != avatar_id]
        self._send(204)

    def log_message(self, *args):
        pass


ThreadingHTTPServer(("127.0.0.1", 8111), Handler).serve_forever()
