"""A server that implements docs/API.md and holds nothing.

This is what a brand new account looks like from the client's side: the
routes all exist, they all answer, and every list is empty. Run it, point
the app at it, and the screens you get are the screens a first-time user
gets.
"""
import json
import os
import time
from email.parser import BytesParser
from email.policy import HTTP
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

USER = {"handle": "rae", "name": "Rae Okonkwo", "email": "rae@example.com"}
AVATARS = []
_next_id = [1]
# What POST /v1/uploads was given, by id, so a trained avatar can show the
# photo it was made from. Nothing is written to disk.
UPLOADS = {}
# How long the stand-in "render" takes. Long enough to watch the gallery
# poll, short enough to wait for: MOCK_TRAIN_SECONDS=5 for a quicker look.
TRAIN_SECONDS = float(os.environ.get("MOCK_TRAIN_SECONDS", "20"))
BASE = "http://127.0.0.1:8111"


def settle_avatars():
    """Finish any render whose time is up, the way HeyGen would.

    A name with "fail" in it fails, so the failed tile can be seen too.
    The first avatar to finish becomes personal if none is: the profile
    picture should not wait for the person to find a button.
    """
    now = time.time()
    for avatar in AVATARS:
        if avatar["status"] == "training" and now - avatar["_t0"] >= TRAIN_SECONDS:
            if "fail" in avatar["name"].lower():
                avatar["status"] = "failed"
                avatar["failureReason"] = (
                    "The mock engine fails any avatar named with \"fail\".")
            else:
                avatar["status"] = "ready"
                avatar["previewUrl"] = f"{BASE}/v1/mock/media/{avatar['_upload']}"
    if not any(a["personal"] for a in AVATARS):
        for avatar in AVATARS:
            if avatar["status"] == "ready":
                avatar["personal"] = True
                break


def public(avatar):
    return {k: v for k, v in avatar.items() if not k.startswith("_")}


def file_part(content_type, raw):
    """The `file` field of a multipart upload, as (bytes, type)."""
    message = BytesParser(policy=HTTP).parsebytes(
        f"Content-Type: {content_type}\r\n\r\n".encode() + raw)
    for part in message.iter_parts():
        if part.get_param("name", header="content-disposition") == "file":
            return part.get_payload(decode=True), part.get_content_type()
    return None, None
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

# Two stand-in AIs, so the app's picker and its per-reply labels have
# something to show. A real engine lists whichever it has connected.
MODELS = [
    {"id": "mock-a", "name": "Mock A", "provider": "Mock", "default": True},
    {"id": "mock-b", "name": "Mock B", "provider": "Mock"},
    # Specialists, so Best fit has somewhere to send a video or an image.
    {"id": "mock-video", "name": "Mock Video", "provider": "Mock",
     "bestFor": ["video"]},
    {"id": "mock-image", "name": "Mock Image", "provider": "Mock",
     "bestFor": ["image"]},
]


def answer(body):
    """A reply that proves the model read the whole conversation.

    It says which model is answering, how many earlier turns it was given,
    and quotes the last reply, whichever model wrote it. That is the
    contract in docs/API.md: every earlier reply arrives as the assistant's
    own turn, so a model picking up another model's conversation carries
    on from it as one model would.
    """
    names = {m["id"]: m["name"] for m in MODELS}
    model = body.get("model") or MODELS[0]["id"]
    history = body.get("history") or []
    prompt = body.get("prompt") or ""
    # The app's polish fallback: when an engine has no /v1/polish, the
    # rewrite is asked for through this route. Answered with a preamble,
    # the way models do, so the app's clean-up is exercised too.
    if prompt.startswith("Rewrite the prompt below"):
        original = prompt.split("Prompt:\n", 1)[-1].strip()
        keep = original.rstrip(".?! ")
        rewrite = (f"{keep} — answered for right now, where I am?"
                   if original.endswith("?") or keep.lower().startswith(
                       ("what", "when", "where", "who", "why", "how"))
                   else f"{keep}. Vertical 1080 × 1920, about 20 seconds, "
                        "for people seeing it for the first time.")
        return [{"id": f"m{len(history) + 1}", "author": "shift",
                 "model": model, "modelName": names.get(model, model),
                 "body": f"Here is the polished prompt: {rewrite}"}]
    asked = ask(body, history)
    if asked is not None:
        asked.update({
            "id": f"m{len(history) + 1}",
            "author": "shift",
            "model": model,
            "modelName": names.get(model, model),
        })
        return [asked]
    replies = [t for t in history if t.get("role") == "assistant"]
    text = (f"I can read all {len(history)} earlier turns of this "
            f"conversation.")
    if replies:
        last = replies[-1]
        wrote = names.get(last.get("model"), "an earlier answer")
        quoted = (last.get("body") or "")[:80]
        text += f" Carrying on from the last reply ({wrote}): \"{quoted}\""
    asked = body.get("prompt", "")
    text += f" You asked: \"{asked}\""
    return [{
        "id": f"m{len(history) + 1}",
        "author": "shift",
        "model": model,
        "modelName": names.get(model, model),
        "body": text,
    }]


FEEL = "What should it feel like?"
WHERE = "Where will it go? Pick any that fit."


def ask(body, history):
    """Questions with answers to tap, the way docs/API.md says to send them.

    "make …" to start a conversation gets a question with `choices`;
    answering it gets one that takes several (`multiSelect`); then it
    answers as usual. "ask me in text" gets the question written out as
    plain text instead, which the client turns into buttons by itself.
    """
    prompt = (body.get("prompt") or "").strip().lower()
    last = history[-1]["body"] if history else ""
    if prompt.startswith("ask me in text"):
        return {"body": "Which length works best?\n"
                        "1. 15 seconds — a quick hook\n"
                        "2. 30 seconds\n"
                        "3. 60 seconds — room for a story"}
    if not history and prompt.split(" ")[0] in ("make", "create", "build"):
        return {
            "body": FEEL,
            "choices": [
                {"label": "Cinematic",
                 "description": "Slow drone shots, golden hour"},
                {"label": "High energy",
                 "description": "Fast cuts on the beat"},
                {"label": "Calm", "description": "Long takes, soft music"},
            ],
        }
    if last.startswith(FEEL):
        return {
            "body": WHERE,
            "choices": ["Instagram Reels", "TikTok", "YouTube", "Website"],
            "multiSelect": True,
        }
    return None


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
    "/v1/models": MODELS,
    # The Suite's weekly boards (Rex's server notes, 23 Sept 2026). A new
    # member is on none of them yet, so every board is an empty list.
    "/v1/boards": {"data": {
        "compete": [], "crowd": [], "credit_hold": [], "credit_use": [],
        "club_pools": [], "connect_week": [], "projected_week": [],
        "lifetime": [],
        "my_pool_standings": {},
        "credit_weights": {"held": 0, "use": 0},
        "connect_window": {"start": None, "end": None},
    }},
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
        if path == "/v1/avatars":
            settle_avatars()
            return self._send(200, [public(a) for a in AVATARS])
        if path.startswith("/v1/mock/media/"):
            stored = UPLOADS.get(path.rsplit("/", 1)[-1])
            if stored is None:
                return self._send(404, {"message": "No such upload."})
            data, kind = stored
            self.send_response(200)
            self.send_header("Content-Type", kind)
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return None
        if path in EMPTY:
            return self._send(200, EMPTY[path])
        self._send(404, {"message": f"No route {path}."})

    def do_POST(self):
        path = self.path.split("?")[0]
        if path == "/v1/messages":
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length) or b"{}")
            return self._send(200, answer(body))
        if path == "/v1/polish":
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length) or b"{}")
            ask = str(body.get("prompt", "")).strip()
            if not ask:
                return self._send(400, {"message": "Nothing to polish."})
            # A stand-in rewrite, marked as the mock's so nobody mistakes
            # it for a model's work. The shape is what matters: {prompt}.
            return self._send(200, {
                "prompt": f"{ask}\n\n(Polished by the mock engine.) "
                          "Say who it is for, the tone, and what to deliver."
            })
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
            raw = self.rfile.read(length)
            data, kind = file_part(self.headers.get("Content-Type", ""), raw)
            if data is None:
                return self._send(400, {"message": "No file in the upload."})
            n = _next_id[0]
            _next_id[0] += 1
            UPLOADS[f"u{n}"] = (data, kind or "application/octet-stream")
            return self._send(200, {"id": f"u{n}"})
        if path == "/v1/avatars":
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length) or b"{}")
            if body.get("consent") is not True:
                return self._send(400, {
                    "message": "Confirm the photo is you before making an "
                               "avatar of it."})
            if body.get("uploadId") not in UPLOADS:
                return self._send(400, {"message": "Upload the photo first."})
            n = _next_id[0]
            _next_id[0] += 1
            avatar = {
                "id": f"avatar-{n}",
                "name": body.get("name") or "Avatar",
                "status": "training",
                "personal": False,
                "_t0": time.time(),
                "_upload": body["uploadId"],
            }
            AVATARS.append(avatar)
            return self._send(200, public(avatar))
        if path.startswith("/v1/avatars/") and path.endswith("/personal"):
            avatar_id = path.split("/")[3]
            settle_avatars()
            target = next((a for a in AVATARS if a["id"] == avatar_id), None)
            if target is None:
                return self._send(404, {"message": f"No avatar {avatar_id}."})
            if target["status"] != "ready":
                return self._send(400, {
                    "message": "Only a finished avatar can be personal."})
            for avatar in AVATARS:
                avatar["personal"] = avatar is target
            return self._send(200, public(target))
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
