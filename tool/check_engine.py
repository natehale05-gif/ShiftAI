#!/usr/bin/env python3
"""Checks a server against what the ShiftAi app reads (docs/API.md).

    python3 tool/check_engine.py BASE_URL --email ... --password ... [--spend] [--image]

Signs in, calls every route the app uses, and prints one line per check:

    ok       it answers in a shape the app reads
    missing  404: a route the app treats as not built and works around
    differs  it answers, in a shape the app will not read (fix these)
    note     it works, and something about it is worth knowing
    skipped  not checked, and why

Read-only by default. --spend also sends two messages, polishes a
prompt, uploads a 1 px image, and saves then deletes one test chat: real
credits on a real server. It never calls DELETE /v1/me, which would
delete the account it signed in with. --image generates one image (through
the first model with bestFor ["image"]) and checks the app could show it:
an attachment on the answer, a vault row with mediaUrl, and a file that
loads with no auth header.

Standard library only. Exit code 1 when anything differs.
"""
import argparse
import json
import sys
import time
import urllib.error
import urllib.request
import uuid

RESULTS = []


def say(kind, what, detail=""):
    RESULTS.append(kind)
    line = f"{kind:<8} {what}"
    if detail:
        line += f": {detail}"
    print(line, flush=True)


class Engine:
    def __init__(self, base, timeout):
        self.base = base.rstrip("/")
        self.token = None
        self.timeout = timeout

    def call(self, method, path, body=None, headers=None, raw=None,
             timeout=None):
        """(status, parsed body or None, content-type, raw bytes)."""
        data = raw if raw is not None else (
            json.dumps(body).encode() if body is not None else None)
        req = urllib.request.Request(self.base + path, data=data,
                                     method=method)
        req.add_header("Accept", "application/json")
        if body is not None and raw is None:
            req.add_header("Content-Type", "application/json")
        if self.token:
            req.add_header("Authorization", f"Bearer {self.token}")
        for k, v in (headers or {}).items():
            req.add_header(k, v)
        try:
            with urllib.request.urlopen(
                    req, timeout=timeout or self.timeout) as res:
                content = res.read()
                return res.status, parse(content), res.headers.get(
                    "Content-Type", ""), content
        except urllib.error.HTTPError as e:
            content = e.read()
            return e.code, parse(content), e.headers.get(
                "Content-Type", ""), content


def parse(content):
    if not content:
        return None
    try:
        return json.loads(content.decode("utf-8", "replace"))
    except ValueError:
        return None


def rows(body):
    """The app accepts [..], {data: [..]}, {rows: [..]} or {items: [..]}."""
    if isinstance(body, list):
        return body
    if isinstance(body, dict):
        for key in ("data", "rows", "items"):
            if isinstance(body.get(key), list):
                return body[key]
    return None


def message_of(body):
    if isinstance(body, dict):
        for key in ("message", "error", "detail"):
            if isinstance(body.get(key), str) and body[key]:
                return body[key]
    return None


def needs(row, keys):
    return [k for k in keys if not isinstance(row.get(k), str) or
            not row.get(k)]


def check_sign_in(engine, email, password):
    status, body, _, _ = engine.call(
        "POST", "/v1/auth/sign-in", {"email": email, "password": password})
    if status != 200 or not isinstance(body, dict):
        say("differs", "POST /v1/auth/sign-in",
            f"{status} {message_of(body) or ''}".strip())
        return False
    missing = [k for k in ("accessToken", "refreshToken") if
               not isinstance(body.get(k), str)]
    if not isinstance(body.get("expiresIn"), (int, float)):
        missing.append("expiresIn")
    user = body.get("user")
    if not isinstance(user, dict) or needs(user, ("handle", "name",
                                                  "email")):
        missing.append("user{handle, name, email}")
    if missing:
        say("differs", "POST /v1/auth/sign-in", "no " + ", ".join(missing))
        return False
    engine.token = body["accessToken"]
    say("ok", "POST /v1/auth/sign-in")
    return True


def check_me(engine):
    status, body, _, _ = engine.call("GET", "/v1/me")
    if status != 200 or not isinstance(body, dict):
        say("differs", "GET /v1/me", f"{status}")
        return
    gone = needs(body, ("handle", "name", "email"))
    say("differs" if gone else "ok", "GET /v1/me",
        "no " + ", ".join(gone) if gone else "")


def check_list(engine, path, required=("id",), optional=False, what=None,
               numbers=()):
    status, body, _, _ = engine.call("GET", path)
    if status == 404 and optional:
        say("missing", f"GET {path}", what or "the app works without it")
        return None
    if status != 200:
        say("differs", f"GET {path}",
            f"{status} {message_of(body) or ''}".strip())
        return None
    items = rows(body)
    if items is None:
        say("differs", f"GET {path}", "not a list, or data/rows/items")
        return None
    bad = [i for i, r in enumerate(items)
           if not isinstance(r, dict) or needs(r, required) or
           any(not isinstance(r.get(k), (int, float)) for k in numbers)]
    if bad:
        say("differs", f"GET {path}",
            f"row {bad[0]} needs {', '.join((*required, *numbers))}")
        return items
    say("ok", f"GET {path}", f"{len(items)} rows")
    return items


def check_vault(engine):
    check_list(engine, "/v1/vault", ("id", "title"))
    eco = check_list(engine, "/v1/ecovault", ("id", "title"))
    if eco:
        anon = [r for r in eco if not r.get("byHandle")]
        if anon:
            say("note", "GET /v1/ecovault",
                f"{len(anon)} rows have no byHandle, so the app shows "
                "them as the viewer's own work")
        if not any("hearts" in r for r in eco):
            say("note", "GET /v1/ecovault",
                "no hearts on any row: the feed shows no counts")
        if not any(r.get("byAvatarUrl") for r in eco):
            say("note", "GET /v1/ecovault",
                "no byAvatarUrl: makers show as initials")


def check_models(engine):
    models = check_list(
        engine, "/v1/models", ("id",), optional=True,
        what="no picker, and every image, video or audio request is held "
             "back with 'No image model is connected yet'")
    if not models:
        if models == []:
            say("note", "GET /v1/models",
                "an empty list: no picker, and image/video requests are "
                "held back")
        return
    defaults = [m for m in models if m.get("default") is True]
    if len(defaults) != 1:
        say("note", "GET /v1/models",
            f"{len(defaults)} marked default; one is expected")
    made = {"image": [], "video": [], "audio": []}
    for m in models:
        for kind in m.get("bestFor") or []:
            if kind in made:
                made[kind].append(m["id"])
    for kind, ids in made.items():
        if ids:
            say("ok", f"GET /v1/models: {kind}", ", ".join(ids))
        else:
            hint = {"image": "Flux or Imagen", "video": "Veo or Sora",
                    "audio": "Suno or Eleven"}[kind]
            say("note", f"GET /v1/models: {kind}",
                f"no model has bestFor [\"{kind}\"], so {kind} requests "
                f"are held back (unless a name like {hint} gives it away)")


def check_avatars(engine):
    avatars = check_list(engine, "/v1/avatars", ("id", "name"))
    for a in avatars or []:
        if a.get("status") not in ("training", "ready", "failed"):
            say("differs", "GET /v1/avatars",
                f"{a.get('id')} status {a.get('status')!r} reads as "
                "training")
        url = str(a.get("previewUrl") or "")
        if url.lower().split("?")[0].endswith(
                (".mp4", ".mov", ".webm", ".m4v", ".m3u8")):
            say("note", "GET /v1/avatars",
                f"{a.get('id')} previewUrl is a video; it belongs in "
                "clipUrl, and the app shows initials until a still comes")


def check_threads(engine, spend):
    status, body, _, _ = engine.call("GET", "/v1/threads")
    if status == 404:
        say("missing", "GET /v1/threads",
            "chats are saved on the device only")
        return
    if status != 200 or rows(body) is None:
        say("differs", "GET /v1/threads", f"{status}")
        return
    say("ok", "GET /v1/threads", f"{len(rows(body))} chats")
    if not spend:
        say("skipped", "PUT/DELETE /v1/threads", "writes; run with --spend")
        return
    tid = f"check-{uuid.uuid4().hex[:10]}"
    chat = {"id": tid, "title": "tool/check_engine.py",
            "updatedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "messages": [{"id": "you-1", "author": "you", "body": "check"}]}
    status, _, _, _ = engine.call("PUT", f"/v1/threads/{tid}", chat)
    if status not in (200, 201, 204):
        say("differs", "PUT /v1/threads/{id}", f"{status}")
        return
    _, body, _, _ = engine.call("GET", "/v1/threads")
    back = [t for t in rows(body) or [] if t.get("id") == tid]
    if not back:
        say("differs", "PUT /v1/threads/{id}",
            "saved, but not in the next GET")
    elif back[0].get("updatedAt") != chat["updatedAt"]:
        say("differs", "PUT /v1/threads/{id}",
            "updatedAt came back changed; the app merges by it")
    else:
        say("ok", "PUT /v1/threads/{id}", "round trip")
    status, _, _, _ = engine.call("DELETE", f"/v1/threads/{tid}")
    say("ok" if status in (200, 204) else "differs",
        "DELETE /v1/threads/{id}", f"{status}")


def check_polish(engine, spend):
    if not spend:
        say("skipped", "POST /v1/polish", "spends credits; run with --spend")
        return
    status, body, _, _ = engine.call("POST", "/v1/polish",
                                     {"prompt": "make a poster"})
    if status in (404, 405):
        say("missing", "POST /v1/polish",
            "the app asks the chat model to rewrite instead")
        return
    text = None
    if isinstance(body, dict):
        inner = body.get("data") if isinstance(body.get("data"),
                                                dict) else body
        for key in ("polished", "polishedPrompt", "result", "text",
                    "prompt"):
            if isinstance(inner.get(key), str) and inner[key].strip():
                text = inner[key]
                break
    if status != 200 or not text:
        say("differs", "POST /v1/polish", f"{status}, no prompt in it")
    elif text.strip() == "make a poster":
        say("differs", "POST /v1/polish",
            "came back unchanged; the app then asks the chat model")
    else:
        say("ok", "POST /v1/polish", " ".join(text.split())[:70])


def ask(engine, body):
    """Sends a message the way the app does; (status, messages, streamed)."""
    status, parsed, ctype, raw = engine.call(
        "POST", "/v1/messages", body,
        headers={"Accept": "text/event-stream, application/json"},
        timeout=180)
    if not ctype.startswith("text/event-stream"):
        return status, rows(parsed), False, message_of(parsed)
    final, texts, error = None, [], None
    event, data = "message", []
    for line in raw.decode("utf-8", "replace").splitlines() + [""]:
        if line == "":
            if data:
                payload = parse("\n".join(data).encode())
                if event == "text" and isinstance(payload, dict):
                    texts.append(payload.get("text") or "")
                elif event == "messages":
                    final = rows(payload)
                elif event == "error":
                    error = message_of(payload) or "error event"
            event, data = "message", []
        elif line.startswith("event:"):
            event = line[6:].strip()
        elif line.startswith("data:"):
            data.append(line[5:].lstrip(" ") if line[5:6] == " "
                        else line[5:])
    if error:
        return status, None, True, error
    if final is None and texts:
        final = [{"id": "streamed", "author": "shift",
                  "body": "".join(texts)}]
    return status, final, True, None


def red_pixel_png():
    """A valid 1x1 PNG, one red pixel."""
    import struct
    import zlib

    def chunk(kind, data):
        return (struct.pack(">I", len(data)) + kind + data +
                struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff))
    header = struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0)
    pixels = zlib.compress(b"\x00\xff\x00\x00")
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) +
            chunk(b"IDAT", pixels) + chunk(b"IEND", b""))


def check_messages(engine, spend):
    if not spend:
        say("skipped", "POST /v1/messages",
            "spends credits; run with --spend")
        return
    status, msgs, streamed, error = ask(engine, {
        "prompt": "Reply with the single word: pong", "private": True,
        "history": []})
    if error or status != 200 or not msgs:
        say("differs", "POST /v1/messages", error or f"{status}")
        return
    bad = [m for m in msgs if not isinstance(m, dict) or
           needs(m, ("id", "author"))]
    if bad:
        say("differs", "POST /v1/messages", "a message has no id or author")
        return
    reply = msgs[-1]
    say("ok", "POST /v1/messages",
        f"{'streamed' if streamed else 'JSON'}: "
        f"{str(reply.get('body'))[:60]!r}")
    if not streamed:
        say("note", "POST /v1/messages",
            "not streamed: replies appear all at once (section 3)")
    if not reply.get("modelName"):
        say("note", "POST /v1/messages",
            "no modelName: the reply is not labelled with its AI")

    # A file, the way the "+" sends one: uploaded, then named by id.
    png = red_pixel_png()
    boundary = uuid.uuid4().hex
    form = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\";"
            f" filename=\"check.png\"\r\nContent-Type: image/png\r\n\r\n"
            ).encode() + png + f"\r\n--{boundary}--\r\n".encode()
    status, body, _, _ = engine.call(
        "POST", "/v1/uploads", raw=form,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"})
    upload = body.get("id") if isinstance(body, dict) else None
    if status != 200 or not isinstance(upload, str):
        say("differs", "POST /v1/uploads", f"{status}, no id")
        return
    say("ok", "POST /v1/uploads", upload)
    status, msgs, _, error = ask(engine, {
        "prompt": "What colour is the attached image? One word.",
        "private": True, "history": [],
        "attachments": [{"uploadId": upload, "name": "check.png",
                         "mimeType": "image/png", "sizeBytes": len(png)}]})
    if error or status != 200 or not msgs:
        say("differs", "POST /v1/messages with attachments",
            error or f"{status}")
        return
    say("note", "POST /v1/messages with attachments",
        f"the image is one red pixel; the model said "
        f"{str(msgs[-1].get('body'))[:60]!r}")


def check_image(engine, enabled):
    """One image, the way the app asks for it, and whether the app can show
    it: the answer names a vault row, the row (or the answer) has the file,
    and the file loads."""
    if not enabled:
        say("skipped", "image generation", "makes an image; run with --image")
        return
    _, body, _, _ = engine.call("GET", "/v1/models")
    models = rows(body) or []
    able = [m for m in models if "image" in (m.get("bestFor") or [])]
    if not able:
        say("differs", "image generation",
            "no model in /v1/models has bestFor [\"image\"], so the app "
            "never sends an image request")
        return
    model = able[0]["id"]
    status, msgs, _, error = ask(engine, {
        "prompt": "Generate an image of a pink flower", "model": model,
        "private": True, "history": []})
    if error or status != 200 or not msgs:
        say("differs", f"image generation ({model})", error or f"{status}")
        return
    made = next((m.get("attachment") for m in msgs
                 if isinstance(m.get("attachment"), dict)), None)
    if not made:
        say("differs", f"image generation ({model})",
            "the answer has no attachment, so the chat shows only text: "
            + repr(str(msgs[-1].get("body"))[:60]))
        return
    say("ok", f"image generation ({model})",
        f"attachment {made.get('fileName')}")
    url = made.get("url") or made.get("mediaUrl")
    row_id = made.get("vaultItemId")
    if not url and row_id:
        _, body, _, _ = engine.call("GET", "/v1/vault")
        row = next((r for r in rows(body) or [] if r.get("id") == row_id),
                   None)
        if row is None:
            say("differs", "made image in /v1/vault",
                f"no row {row_id!r}: 'Open in Vault' finds nothing and the "
                "chat has no picture to show")
            return
        url = row.get("mediaUrl") or row.get("thumbnailUrl")
        if not url:
            say("differs", "made image in /v1/vault",
                f"row {row_id!r} has no mediaUrl or thumbnailUrl, so the "
                "chat shows a file name and no picture")
            return
        say("ok", "made image in /v1/vault", url)
    if not url:
        say("differs", "made image", "no url on the answer and no vaultItemId")
        return
    req = urllib.request.Request(url, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=engine.timeout) as res:
            kind = res.headers.get("Content-Type", "")
            cors = res.headers.get("Access-Control-Allow-Origin")
            res.read(64)
            if not kind.startswith("image/"):
                say("differs", "made image file",
                    f"{url} answers {kind or 'no content type'}, not an image")
                return
            say("ok", "made image file", f"{kind}, no auth header needed")
            if not cors:
                say("note", "made image file",
                    "no Access-Control-Allow-Origin: fine where the app is "
                    "served from the same origin, but the web app on any "
                    "other origin cannot draw it")
    except urllib.error.HTTPError as e:
        say("differs", "made image file",
            f"{e.code} without a token: the app loads it with no "
            "Authorization header")
    except Exception as e:  # noqa: BLE001 - report anything else plainly
        say("differs", "made image file", f"{url}: {e}")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("base", help="e.g. https://app.shiftai.club/app-preview/api")
    ap.add_argument("--email", required=True)
    ap.add_argument("--password", required=True)
    ap.add_argument("--image", action="store_true",
                    help="also generate one image and check the app can show it")
    ap.add_argument("--spend", action="store_true",
                    help="also send messages, polish, upload, save a chat")
    ap.add_argument("--timeout", type=float, default=20,
                    help="seconds per read (the app gives 20)")
    args = ap.parse_args()

    engine = Engine(args.base, args.timeout)
    if not check_sign_in(engine, args.email, args.password):
        return 1
    check_me(engine)
    check_list(engine, "/v1/standings", ("name",),
               numbers=("rank", "earnings"))
    check_list(engine, "/v1/trophies", ("id",))
    check_vault(engine)
    for path in ("/v1/notes", "/v1/agents/runs", "/v1/agents/jobs",
                 "/v1/designs", "/v1/connections"):
        check_list(engine, path, ("id",))
    check_models(engine)
    check_avatars(engine)
    check_threads(engine, args.spend)
    check_polish(engine, args.spend)
    check_messages(engine, args.spend)
    check_image(engine, args.image)
    say("skipped", "DELETE /v1/me", "it would delete this account")

    differs = RESULTS.count("differs")
    print(f"\n{RESULTS.count('ok')} ok, {differs} differ, "
          f"{RESULTS.count('missing')} missing, {RESULTS.count('note')} "
          f"notes")
    return 1 if differs else 0


if __name__ == "__main__":
    sys.exit(main())
