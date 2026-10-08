"""A server that implements docs/API.md and holds nothing.

This is what a brand new account looks like from the client's side: the
routes all exist, they all answer, and every list is empty. Run it, point
the app at it, and the screens you get are the screens a first-time user
gets.
"""
import json
import os
import re
import threading
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
# Saved chats by id, the way /v1/threads keeps them.
THREADS = {}
# What the image and video models made, newest first: /v1/vault.
VAULT = []
# How long the stand-in "render" takes. Long enough to watch the gallery
# poll, short enough to wait for: MOCK_TRAIN_SECONDS=5 for a quicker look.
TRAIN_SECONDS = float(os.environ.get("MOCK_TRAIN_SECONDS", "20"))
# A message with "slow" in it waits this long before its answer, like a
# model writing a long one or making a picture: long enough to see "Still
# working" and try Stop. MOCK_SLOW_SECONDS=5 for a quicker look.
SLOW_SECONDS = float(os.environ.get("MOCK_SLOW_SECONDS", "30"))
# Answers are written out a word at a time (server-sent events) when the
# app asks for text/event-stream, as docs/API.md describes. MOCK_STREAM=0
# answers with plain JSON instead, the way a server that does not stream
# does.
STREAM = os.environ.get("MOCK_STREAM", "1") != "0"
# MOCK_MODELS_LATE=6: the first GET /v1/models takes that many seconds, so
# the app opens before it knows which models there are.
MODELS_LATE = float(os.environ.get("MOCK_MODELS_LATE", "0"))
# MOCK_EDITS=ignore: the image model draws a new picture from the words of
# an edit and ignores the picture sent with it, as the preview did on
# 7 Oct ("make one of the petals blue" came back as a different flower).
EDITS_IGNORED = os.environ.get("MOCK_EDITS", "") == "ignore"
# MOCK_DELAY_MS=2500: every GET under /v1 answers that much later, like a
# server relaying each read to the Suite, to time how the app opens.
DELAY = float(os.environ.get("MOCK_DELAY_MS", "0")) / 1000
_models_late_done = []
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
    {"id": "mock-music", "name": "Mock Music", "provider": "Mock",
     "bestFor": ["audio"]},
]

MODELS_BY_ID = {m["id"]: m["name"] for m in MODELS}


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
    made = make(body, model, history)
    if made is not None:
        return [made]
    asked = ask(body, history)
    if asked is not None:
        asked.update({
            "id": f"m{len(history) + 1}",
            "author": "shift",
            "model": model,
            "modelName": names.get(model, model),
        })
        return [asked]
    # Markdown, the way real models answer, so the thread's rendering of
    # it can be seen: ask for a "shot list".
    if "shot list" in (prompt or "").lower():
        return [{"id": f"m{len(history) + 1}", "author": "shift",
                 "model": model, "modelName": names.get(model, model),
                 "body": MARKDOWN_REPLY}]
    replies = [t for t in history if t.get("role") == "assistant"]
    text = (f"I can read all {len(history)} earlier turns of this "
            f"conversation.")
    # The files sent with it, by upload id, and what they are: proof the
    # file itself arrived, not only its name.
    files = body.get("attachments") or []
    if files:
        seen = []
        for f in files:
            stored = UPLOADS.get(f.get("uploadId"))
            size = f"{len(stored[0])} bytes" if stored else "not uploaded"
            seen.append(f"{f.get('name')} ({f.get('mimeType')}, {size})")
        text = f"I have {len(files)} file(s): {', '.join(seen)}. " + text
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


COLOURS = {"purple": (170, 70, 255), "blue": (60, 120, 255),
           "yellow": (255, 210, 50), "red": (240, 40, 40),
           "green": (60, 200, 110), "orange": (255, 140, 30)}


def picture_png(size=256, colour=(255, 60, 150)):
    """A made "picture": a pink bloom on a dark ground, as a real PNG.

    Enough to see the chat draw what was made, with no image library.
    """
    import struct
    import zlib
    rows = []
    mid = size / 2
    for y in range(size):
        row = bytearray(b"\x00")
        for x in range(size):
            d = ((x - mid) ** 2 + (y - mid) ** 2) ** 0.5 / mid
            if d < 0.55:
                k = 1 - d / 0.55
                row += bytes(min(255, int(c + (255 - c) * 0.5 * k))
                             for c in colour)
            else:
                row += bytes((20, 12, int(30 + 30 * y / size)))
        rows.append(bytes(row))

    def chunk(kind, data):
        return (struct.pack(">I", len(data)) + kind + data +
                struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff))
    header = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) +
            chunk(b"IDAT", zlib.compress(b"".join(rows))) +
            chunk(b"IEND", b""))


def make(body, model, history):
    """What an image or video model answers with: the file, in the vault.

    The row is in /v1/vault before the answer goes, as docs/API.md asks,
    so the app's "Open in Vault" has something to open. There is no real
    file behind it; the vault draws its seeded art for a row without one.
    """
    kind = {"mock-image": "image", "mock-video": "video",
            "mock-music": "audio"}.get(model)
    if kind is None:
        return None
    if kind == "audio":
        return make_track(body, model, history)
    n = _next_id[0]
    _next_id[0] += 1
    prompt = (body.get("prompt") or "").strip()
    row = {
        "id": f"v{n}", "title": prompt[:60] or "Untitled", "kind": kind,
        "mediaType": kind, "prompt": prompt, "model": MODELS_BY_ID[model],
        "createdAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "credits": 4 if kind == "image" else 14,
        "aspect": 1.0 if kind == "image" else 0.5625,
        "published": False,
        **({"durationSeconds": 20, "width": 1080, "height": 1920}
           if kind == "video" else {"width": 1024, "height": 1024}),
    }
    # The file itself, served from this mock like an upload, so the chat
    # and the vault have a real picture to draw. A video gets a still.
    # An edit: a picture sent back with the prompt (a vault reference) is
    # changed rather than drawn from nothing, in the colour asked for.
    source = next((f for f in body.get("attachments") or []
                   if f.get("vaultItemId")), None)
    if EDITS_IGNORED:
        source = None
    colour = next((rgb for word, rgb in COLOURS.items()
                   if word in prompt.lower()), (255, 60, 150))
    UPLOADS[f"made-{n}"] = (picture_png(colour=colour), "image/png")
    still = f"{BASE}/v1/mock/media/made-{n}"
    row["thumbnailUrl"] = still
    if kind == "image":
        row["mediaUrl"] = still
    name = "png" if kind == "image" else "mp4"
    answer = {
        "id": f"m{len(history) + 1}", "author": "shift", "model": model,
        "modelName": MODELS_BY_ID[model],
        "eyebrow": f"ShiftAi · {kind.title()}",
        "body": (f"Edited {source.get('name')}: {prompt}" if source
                 else f"Made it: {prompt}"),
        "attachment": {
            "fileName": f"mock-{n}.{name}", "kind": kind,
            "meta": ("1024 × 1024 · 4 CREDITS" if kind == "image"
                     else "20S · 1080 × 1920 · 14 CREDITS"),
            "vaultItemId": row["id"],
            # Which picture this one changed: the server saying it was an
            # edit of what it was sent, not a new picture from the words.
            **({"editedFrom": source["vaultItemId"]} if source else {}),
        },
    }
    misbehave(made_case(prompt), n, row, answer)
    return answer


def tone_wav(seconds=3.0, hz=440.0, rate=22050):
    """A made "song": a few seconds of a soft tone, as a real WAV."""
    import io
    import math
    import struct
    import wave
    out = io.BytesIO()
    with wave.open(out, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        frames = bytearray()
        for i in range(int(seconds * rate)):
            fade = min(1.0, i / 2000, (seconds * rate - i) / 2000)
            v = 0.3 * fade * math.sin(2 * math.pi * hz * i / rate)
            frames += struct.pack("<h", int(v * 32767))
        w.writeframes(bytes(frames))
    return out.getvalue()


def make_track(body, model, history):
    """What a music model answers with: a track in the vault.

    The vault row says what the file is (mediaType "audio"; kind stays
    "image" as in the contract's first draft) and the answer calls it
    "audio". On 8 Oct SHIFT Music's "country song" was drawn by the chat
    as a picture that "did not load".
    """
    n = _next_id[0]
    _next_id[0] += 1
    prompt = (body.get("prompt") or "").strip()
    UPLOADS[f"song-{n}"] = (tone_wav(), "audio/wav")
    url = f"{BASE}/v1/mock/media/song-{n}"
    row = {
        "id": f"v{n}", "title": prompt[:60] or "Untitled", "kind": "image",
        "mediaType": "audio", "prompt": prompt, "model": MODELS_BY_ID[model],
        "createdAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "credits": 6, "aspect": 1.0, "published": False,
        "durationSeconds": 3, "mediaUrl": url,
    }
    VAULT.insert(0, row)
    return {
        "id": f"m{len(history) + 1}", "author": "shift", "model": model,
        "modelName": MODELS_BY_ID[model], "eyebrow": "ShiftAi · Music",
        "body": "Instrumental track",
        "attachment": {"fileName": f"track-{n}.wav", "kind": "audio",
                       "meta": "0:03 · 6 CREDITS", "vaultItemId": row["id"],
                       "url": url},
    }


# The ways a real engine has handed back a made picture that the chat
# could not show. Put "mock:<case>" in the prompt ("generate an image of a
# flower mock:late"), or set MOCK_MADE=<case> for every one:
#
#   late      the vault row is saved 8 s after the answer, which has no link
#   lost      the vault row is never saved, and the answer has no link
#   broken    the full-size links 404; only the thumbnail loads
#   relative  every link is relative to the engine ("/v1/mock/media/...")
#   renamed   the answer's vaultItemId is a job id; the row is found by name
#   markdown  no attachment: the picture is a Markdown image in the words
#   nocors    the full-size file is sent with no Access-Control-Allow-Origin
MADE_CASES = ("late", "lost", "broken", "relative", "renamed", "markdown", "nocors")


def made_case(prompt):
    named = next((c for c in MADE_CASES if f"mock:{c}" in prompt), None)
    return named or os.environ.get("MOCK_MADE", "")


def misbehave(case, n, row, answer):
    still = row["thumbnailUrl"]
    if case == "late":
        threading.Timer(8, lambda: VAULT.insert(0, row)).start()
        return
    if case == "lost":
        return
    if case == "broken":
        row["mediaUrl"] = f"{BASE}/v1/mock/media/gone-{n}"
        answer["attachment"]["url"] = row["mediaUrl"]
    elif case == "relative":
        local = f"/v1/mock/media/made-{n}"
        row["mediaUrl"] = row["thumbnailUrl"] = local
        answer["attachment"]["url"] = local
    elif case == "renamed":
        name = f"image-{n:08x}.png"
        UPLOADS[name] = UPLOADS[f"made-{n}"]
        row["mediaUrl"] = row["thumbnailUrl"] = f"{BASE}/v1/mock/media/{name}"
        answer["attachment"].update(fileName=name, vaultItemId=f"job-{n}")
    elif case == "markdown":
        del answer["attachment"]
        answer["body"] += f"\n\n![{row['title']}]({still})"
    elif case == "nocors":
        UPLOADS[f"nocors-{n}"] = UPLOADS[f"made-{n}"]
        answer["attachment"]["url"] = f"{BASE}/v1/mock/media/nocors-{n}"
    VAULT.insert(0, row)


MARKDOWN_REPLY = """### Shot list

A **tight** 20 second cut, *handheld*, for [Reels](https://example.com).

1. **Hook:** the ferry horn, 0:00 to 0:02
2. The crossing
   - wide from the deck
   - close on the wake
3. ~~Drone~~ no drone: it reads as stock

> Keep every shot under three seconds.

```
ffmpeg -i crossing.mp4 -t 20 -vf scale=1080:1920 reel.mp4
```

Trim with `ffmpeg` and post by **6 pm**."""


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
        self.send_header("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        if raw:
            self.wfile.write(raw)

    def _stream(self, reply):
        """The answer as server-sent events: its words, then the whole."""
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()

        def event(name, data):
            self.wfile.write(
                f"event: {name}\ndata: {json.dumps(data)}\n\n".encode())
            self.wfile.flush()

        for message in reply:
            for word in re.findall(r"\S+\s*", message.get("body") or ""):
                event("text", {"text": word})
                time.sleep(0.04)
        event("messages", reply)

    def do_OPTIONS(self):
        self._send(204)

    def do_GET(self):
        path = self.path.split("?")[0]
        if DELAY and path.startswith("/v1/") and \
                not path.startswith("/v1/mock/"):
            time.sleep(DELAY)
        if path == "/v1/league":
            return self._send(200, league_placement() if LOCATION["set"] else {})
        if path == "/v1/threads":
            return self._send(200, sorted(
                THREADS.values(), key=lambda t: t.get("updatedAt", ""),
                reverse=True))
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
            if not path.rsplit("/", 1)[-1].startswith("nocors-"):
                self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return None
        if path == "/v1/vault":
            return self._send(200, VAULT)
        if path == "/v1/models" and MODELS_LATE and not _models_late_done:
            # The first read only: the load runs past the app's first
            # screen and it opens with no models, as it did on 6 Oct.
            _models_late_done.append(True)
            time.sleep(MODELS_LATE)
        if path in EMPTY:
            return self._send(200, EMPTY[path])
        self._send(404, {"message": f"No route {path}."})

    def do_POST(self):
        path = self.path.split("?")[0]
        if path == "/v1/messages":
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length) or b"{}")
            if "slow" in str(body.get("prompt", "")).lower():
                time.sleep(SLOW_SECONDS)
            try:
                reply = answer(body)
                if STREAM and "text/event-stream" in self.headers.get(
                        "Accept", ""):
                    return self._stream(reply)
                return self._send(200, reply)
            except (BrokenPipeError, ConnectionResetError):
                # Stop in the app: the caller cancelled and went away.
                print("messages: the caller stopped waiting", flush=True)
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

    def do_PUT(self):
        path = self.path.split("?")[0]
        if path.startswith("/v1/threads/"):
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length) or b"{}")
            body["id"] = path.split("/")[3]
            THREADS[body["id"]] = body
            return self._send(200, body)
        self._send(404, {"message": f"No route {path}."})

    def do_DELETE(self):
        path = self.path.split("?")[0]
        if path.startswith("/v1/threads/"):
            THREADS.pop(path.split("/")[3], None)
            return self._send(204)
        if path.startswith("/v1/ecovault/") and path.endswith("/save"):
            return self._send(200, {"id": path.split("/")[3], "saved": False})
        if path.startswith("/v1/avatars/"):
            avatar_id = path.split("/")[3]
            AVATARS[:] = [a for a in AVATARS if a["id"] != avatar_id]
        self._send(204)

    def log_message(self, *args):
        pass


ThreadingHTTPServer(("127.0.0.1", 8111), Handler).serve_forever()
