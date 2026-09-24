# Server work for the ShiftAi app — brief for Claude Code

You are working on the server behind the ShiftAi app (the Flutter client
in `natehale05-gif/ShiftAI`). The client talks to a JSON API under a base
URL; the team's preview is `https://app.shiftai.club/app-preview/api`.
Every route below is prefixed with that base, e.g. `GET <base>/v1/models`.

The client side of everything here is **already built and shipped**. It
degrades gracefully when a route is missing, which is why these gaps show
up as "nothing happens" rather than crashes. This brief lists what the
server still has to do, most visible first.

**The full contract is `docs/API.md` in the ShiftAI repo.** Where this
brief and that file disagree, `docs/API.md` wins. The shapes below are
copied from it so you can work without it open.

## Before you start

1. Find where the preview's existing `/v1/*` routes live (`/v1/me`,
   `/v1/messages`, `/v1/vault` and so on already answer). Add the new
   routes alongside them, using the same auth middleware: every request
   carries `Authorization: Bearer <accessToken>`.
2. The ShiftAi repo has a reference server, `tool/mock_engine.py`. It is
   small and implements every route here with empty data. When a shape is
   unclear, read it: it is exactly what the client accepts.
3. The rules the client relies on:
   - Lists may be bare `[...]` or wrapped in `{"data": [...]}`,
     `{"rows": [...]}` or `{"items": [...]}`.
   - Extra fields are ignored. Missing *required* fields are a hard error.
   - Errors: any non-2xx, with a human sentence in `message` (or `error`
     or `detail`). The person sees that sentence verbatim, so write it for
     them, not for a log.
   - A **404 on an optional route means "not built"**. The client quietly
     falls back. Do not answer 200 with an empty stub for a route you
     have not built: `[]` from `/v1/models` means "no models", not "no
     list".

## What the preview does today (24 Sept 2026)

| Route | Today | Effect in the app |
|---|---|---|
| `GET /v1/models` | not listed | No model picker. Every image, video or audio request is **held back** with "No image model is connected yet". |
| `POST /v1/messages` | answers, chat model only | Asked "generate an image of Miami", the chat model replied "I can't generate images" (fixed in the app). |
| `/v1/threads` | missing | Chats are saved on the device only; they do not follow the account. |
| `POST /v1/polish` | missing | The sparkle button falls back to asking the chat model for a rewrite. Works, but costs a full message. |
| `/v1/avatars` | answers `[]` | The gallery is empty; nobody can train an avatar. |
| `DELETE /v1/me` | missing | **Blocks the App Store submission** (Guideline 5.1.1(v)). |

---

## 1. `GET /v1/models`: list the models, and say what each is for

This is the single most visible gap. Until it exists, the app refuses to
send anything that asks for an image, a video or audio, because it cannot
tell which of your models make them.

```json
[{ "id": "claude-opus-5-5", "name": "Claude Opus 5.5", "provider": "Anthropic",
   "default": true },
 { "id": "veo-3", "name": "Veo 3", "provider": "Google", "bestFor": ["video"] },
 { "id": "flux-pro", "name": "Flux Pro", "provider": "BFL", "bestFor": ["image"] }]
```

- `id`, `name` and `provider` are required. `default: true` marks the one
  that answers when nothing else fits. Mark exactly one.
- `bestFor` takes `image`, `video`, `audio`, `code`, `writing` and
  `research`. **Set it on every image, video and audio model.** Without
  it the client guesses from the name (Sora, Veo, Runway, Kling → video;
  DALL·E, Imagen, Flux, Midjourney, Ideogram → image; Suno, Udio, Eleven →
  audio). A model it cannot place is treated as a chat model, and a chat
  model is never sent a request for an image, video or audio.
- Order is the picker's order.
- List only models this account can actually use right now.

## 2. `POST /v1/messages`: honour `model` and `history`, and make the thing

The client now picks one model per message ("Best fit") and sends it:

```json
{ "prompt": "Now make it shorter",
  "private": false,
  "model": "claude-opus-5-5",
  "avatarId": "a1",
  "history": [
    { "role": "user", "body": "Write a caption for the ferry clip" },
    { "role": "assistant", "model": "gpt-x",
      "body": "Morning light on the harbour, one crossing at a time." }
  ] }
```

**`model`** is which AI answers. If it is missing, the server chooses. An
id you do not have is a 400 with a sentence.

**`history`** is the whole conversation before `prompt`, oldest first.
The client sends it every time, so the server does not need to keep the
thread. Use it like this:

1. Give the chosen model every turn in order, then `prompt` as the newest
   user turn.
2. Send each earlier reply as the **assistant's own turn, whichever model
   wrote it**. Do not relabel another model's reply as a user message,
   and do not write "another AI said" into it. The turn's `model` field is
   for your records only; leave it out of what the model sees. This is
   what lets several models carry on as one voice.
3. Give every model the same Suite system prompt, so the voice does not
   change when the model does.
4. Lists and attachments from earlier replies are already written into
   `body` as text (`- item`, `[Attached: file.mp4]`), so pass `body` as
   it is.

**Answer with messages**, and say who wrote each one:

```json
[{ "id": "m4", "author": "shift", "model": "claude-opus-5-5",
   "modelName": "Claude Opus 5.5", "eyebrow": "ShiftAi · Chat",
   "body": "Harbour light, one crossing." }]
```

Only `id` and `author` (`"shift"`) are required. The client labels the
reply with `modelName` and sends `model` back in the next `history`.

**When the model is an image, video or audio model, generate the file.**
Do not route it to a chat model. Save the result as a vault row (see
`/v1/vault` in `docs/API.md`: `mediaType`, `mediaUrl`, `thumbnailUrl`),
then answer with an attachment that points at that row:

```json
[{ "id": "m5", "author": "shift", "model": "flux-pro", "modelName": "Flux Pro",
   "eyebrow": "ShiftAi · Image",
   "body": "Miami at golden hour, from the water.",
   "attachment": { "fileName": "miami-golden-hour.png", "kind": "image",
                   "meta": "1024 × 1024 · 4 CREDITS", "vaultItemId": "v-123" } }]
```

- `kind` is `image` or `video`. Audio goes as `image` for now, with
  `mediaType: "audio"` on the vault row.
- The row must already be in `GET /v1/vault` by the time you answer.
  Tapping the card opens that vault item.
- The app waits up to **3 minutes** for `/v1/messages` (every other
  route gets 20 s). After 20 s it tells the person it is still working
  and offers Stop. A render that takes longer than 3 minutes should
  answer at once with a "working on it" message and put the row in the
  vault when it finishes.
- **Stop cancels the request**: the app closes the connection. When the
  caller goes away, stop the model call and do not charge for it, if the
  provider allows that.

**`private: true`** means do not retain the exchange anywhere: no logs of
the content, and nothing in `/v1/threads`.

**`avatarId`** is optional and names one of this creator's own `ready`
avatars. Anything else is a 400 with a sentence. **No `avatarId` means the
built-in avatar `shiftai-default`** (see section 6).

**Refusals** (out of credits, moderation, provider down) are the normal
error shape with a sentence in `message`. The person sees it.

## 3. `/v1/threads`: saved chats that follow the account

| Method | Path | Body | Returns |
|---|---|---|---|
| GET | `/v1/threads` | — | this account's chats, newest first |
| PUT | `/v1/threads/{id}` | the chat | the chat |
| DELETE | `/v1/threads/{id}` | — | 204 |

```json
{ "id": "chat-1727178000000000", "title": "Plan a shoot at the ferry terminal",
  "updatedAt": "2026-09-24T14:20:00Z",
  "messages": [
    { "id": "you-1", "author": "you", "body": "Plan a shoot at the ferry terminal" },
    { "id": "m1", "author": "shift", "body": "…", "model": "claude-opus-5-5",
      "modelName": "Claude Opus 5.5" }] }
```

- The id is the client's. `PUT` creates or replaces the whole chat. It is
  sent after every message and every answer, so make it an upsert and
  keep it cheap.
- Scope everything to the signed-in account. One account must never see
  another's chats: a thread id from another account is a 404.
- Store `messages` as opaque JSON. Messages may also carry `bullets`,
  `attachment`, `choices`, `multiSelect` and `eyebrow`; keep whatever
  arrives and give it back unchanged.
- The client merges your list with the device's by id and keeps the
  newer `updatedAt`, so return `updatedAt` exactly as it was sent.
- The Suite's own `chat/threads` storage can back these.

## 4. `POST /v1/polish`: the sparkle button

Body `{ "prompt": "make a poster" }`. Answer `{ "prompt": "<the fuller brief>" }`.

- The answer is the rewritten prompt only: no "Here is your polished
  prompt:", and no quotes around it.
- It must never be the input unchanged. If there is nothing to add,
  still expand it: a one-liner is never "already a full brief".
- The client also reads `polished`, `polishedPrompt`, `result` or `text`,
  and looks inside a `data` envelope, so relaying the Suite's
  `image/polish-prompt` answer unchanged works.
- It is optional. Until it exists, answer 404 and the client asks the chat
  model instead.

## 4b. Stream the answer (optional, and worth it)

The app now asks `/v1/messages` for `text/event-stream` as well as JSON.
Answer JSON and nothing changes. Stream it and the reply appears word by
word instead of all at once after a wait:

```
event: text
data: {"text": "Harbour light, "}

event: text
data: {"text": "one crossing."}

event: messages
data: [ ...the same JSON array you return today... ]
```

- `text` is the next piece only, not everything so far.
- `messages` is sent last, and is the finished answer exactly as the
  non-streaming route returns it (model, modelName, choices,
  attachment). It replaces what was streamed.
- `event: error` with `{"message": "..."}` is a refusal the person sees.
- Map it straight from the provider's stream: for Anthropic, each
  `content_block_delta` text becomes one `text` event.
- For an image or video model there is nothing to stream; answer JSON.
- `python3 tool/mock_engine.py` streams this way, so `curl -N` against it
  shows the exact bytes.

## 5. Questions answered with buttons

When a model needs to ask before going on, the app draws the answers as
buttons, the way Claude does. Tapping one sends its `label` as the
person's next message. Put this on the reply:

```json
[{ "id": "m2", "author": "shift",
   "body": "What should it feel like?",
   "choices": [
     { "label": "Cinematic", "description": "Slow drone shots, golden hour" },
     { "label": "High energy", "description": "Fast cuts on the beat" },
     "Calm"],
   "multiSelect": false }]
```

The simplest way to get this from any model is to give it an `ask_user`
tool with schema `{ question: string, options: [{label, description?}],
multiSelect: boolean }`. When the model calls it, answer with the tool's
input as this message (`body` = question, `choices` = options) and **end
the turn there**. `choices` holds at most 8 entries. The client also
accepts `question: { options: [...], multiSelect }` in place of `choices`.

## 6. `/v1/avatars`: real training

The app side is complete: a consent screen, photo checks, the gallery
polling every 15 s while one trains, and the profile picture. The server
needs:

- `GET /v1/avatars` returns this creator's avatars:
  ```json
  [{ "id": "a1", "name": "Everyday", "status": "ready", "personal": true,
     "previewUrl": "https://…/a1.png", "clipUrl": "https://…/a1.mp4" },
   { "id": "a3", "name": "Hat", "status": "failed", "personal": false,
     "failureReason": "The face was covered. Try a photo without a hat." }]
  ```
  `status` is `training`, `ready` or `failed`. `previewUrl` is a **still
  image** (PNG, JPEG or WebP), sent only once the avatar is `ready`; put
  any video in `clipUrl`. The client polls this route every 15 s, so keep
  it cheap.
- `POST /v1/uploads` (multipart, field `file`) returns `{ "id": "u1" }`.
  That route already exists; the photo arrives through it.
- `POST /v1/avatars` with `{ "uploadId": "u1", "name": "…", "consent": true }`
  records the likeness consent (the Suite's `likeness-consent` route),
  starts training with HeyGen, and **answers at once** with the avatar at
  `status: "training"`. Without `consent: true`, answer 400.
- `POST /v1/avatars/{id}/personal` makes that avatar the one on the
  profile and the leaderboard. Only a `ready` avatar can be personal; the
  server keeps exactly one personal. When an account's first avatar
  finishes and none is personal, make it personal automatically.
- `DELETE /v1/avatars/{id}` returns 204.
- Put the personal avatar's `previewUrl` on that creator's own row in
  `/v1/standings` as `avatarUrl`.
- **The built-in avatar `shiftai-default`.** Train it once on the server
  from `docs/avatars/shiftai-default-1024.jpg` in the ShiftAI repo. It is
  AI-generated for ShiftAi, not a real person, so no consent is needed.
  Use it whenever `avatarId` is missing or is `"shiftai-default"`. It is
  never returned by `GET /v1/avatars` and is never anyone's `personal`
  avatar.

## 6b. EcoVault is a feed now: two optional fields

EcoVault shows as an Instagram-style feed. Each `/v1/ecovault` row can
carry:

- `hearts`: the number of people who have hearted it. It is shown as
  "1,284 hearts". Leave it out and no count is shown.
- `byAvatarUrl`: the maker's personal avatar still (its `previewUrl`).
  Initials are shown without it.

Everything else in the feed (handle, model, title, prompt, date) comes
from the fields the rows already carry.

## 7. `DELETE /v1/me` (blocks the App Store)

Apple rejects any app that lets people create an account but not delete
it from inside the app. The button and its confirmation already exist in
the app.

- Answer 204 once the account, vault, notes, designs, threads and avatars
  are deleted, and revoke every refresh token.
- If deletion is queued, answer 202 with the completion date in `message`.

## 8. Still read-only in the app, for when you get to them

| Method | Path | Body | Returns |
|---|---|---|---|
| PATCH | `/v1/me` | `{ "handle": "…" }` | the creator (same shape as `GET /v1/me`); a taken handle is 400 with a sentence |
| PATCH | `/v1/vault/{id}` | `{ "title": "…" }` | the item |
| POST | `/v1/vault/{id}/publish` | — | the item, `published: true` |
| DELETE | `/v1/vault/{id}` | — | 204 |

---

## How to check your work

1. Compare against the mock: in the ShiftAI repo run
   `python3 tool/mock_engine.py` (it serves on 127.0.0.1:8111) and
   `curl` the same route on both. Your shape should be a superset of the
   mock's.
2. Then sign in to the app against the preview and try:
   - **"generate an image of Miami"** should get an image card from the
     image model, with no "I can't generate images" and no "No image
     model is connected".
   - **"write a caption for it"** should get a text reply from the chat
     model, which can see the image turn in `history`.
   - Close the app and sign in on another device: the chat should be in
     Recents.
   - The sparkle on "make a poster" should give a full brief back in the
     bar.
3. **Never** show one account another's data: threads, avatars, the vault
   and the standings are all scoped to the bearer token.
