# The SHIFT engine contract

This is what the client calls. `lib/data/api/http_repository.dart`
implements it and `test/repository_test.dart` proves the client's half
against a fake server — if this file and that code ever disagree, the code
is what runs, so change both together.

Base URL is configured at runtime (`shift-backend` in shared preferences,
or the Engine card in a debug build). Everything is JSON. Every request
carries `Authorization: Bearer <token>` when signed in.

## Checking your work against the client

`tool/mock_engine.py` is a ~70-line Python server that implements every
route below and holds nothing — every list empty, sign-in always
succeeds. Run it, point the app at it, and you see exactly what a brand
new account sees:

```
python3 tool/mock_engine.py          # serves on 127.0.0.1:8111
```

It is also the quickest way to check a real server: swap the base URL
and any screen that changes is a place your shapes differ from this
document.

## What the client assumes

- **Lists may be bare or wrapped.** `[...]`, `{"data": [...]}`,
  `{"rows": [...]}` and `{"items": [...]}` are all accepted, so the server
  can use whichever convention it already has.
- **Extra fields are ignored.** Send more than this document lists and
  nothing breaks.
- **Missing required fields are a hard error.** The client raises
  `malformed` rather than drawing a half-empty screen.
- **Unknown enum values fall back**, they do not throw: an unrecognised
  run status reads as `working`, an unrecognised tier as `bronze`.

## Reads

The client fetches these eleven in parallel on start and on refresh. If
you would rather answer once, add `GET /v1/snapshot` returning an object
with these eleven under their names and change `load()` to call it — the
rest of the app does not care.

| Method | Path | Returns |
|---|---|---|
| GET | `/v1/me` | the signed-in creator |
| GET | `/v1/standings` | the weekly board, every row |
| GET | `/v1/trophies` | which trophies are earned, and progress |
| GET | `/v1/vault` | the creator's media |
| GET | `/v1/ecovault` | everyone's published media |
| GET | `/v1/notes` | notes, newest first |
| GET | `/v1/agents/runs` | agent runs |
| GET | `/v1/agents/jobs` | jobs |
| GET | `/v1/designs` | saved designs |
| GET | `/v1/connections` | the connector catalogue and which are live |
| GET | `/v1/week` | the pool and the payout line |
| GET | `/v1/avatars` | this creator's animated avatars |

### `/v1/me`

```json
{ "handle": "shiftai", "name": "ShiftAi", "email": "demo@shiftai.club",
  "initials": "NH" }
```

`handle`, `name` and `email` are required. `initials` is derived from the
name when absent.

### `/v1/avatars`

```json
[{ "id": "a1", "name": "Everyday", "status": "ready", "personal": true,
   "previewUrl": "https://cdn.example.com/avatars/a1.png",
   "clipUrl": "https://cdn.example.com/avatars/a1.mp4" },
 { "id": "a2", "name": "Studio lighting", "status": "training",
   "personal": false },
 { "id": "a3", "name": "Hat", "status": "failed", "personal": false,
   "failureReason": "The face was covered. Try a photo without a hat." }]
```

`id` and `name` are required. `status` is one of `training`, `ready` or
`failed`, and falls back to `training` if it is anything else — a status
the client does not recognise should not read as ready.

- **`previewUrl` is a still image** (PNG, JPEG or WebP) — HeyGen's
  preview image, not its video. It is the profile picture, the
  leaderboard face and the gallery tile, and every one of those is drawn
  as a picture. A video here cannot be drawn: the client moves anything
  ending `.mp4`, `.mov`, `.webm`, `.m4v` or `.m3u8` to `clipUrl` and
  shows initials until a still arrives. Send it once `status` is
  `ready`, omit it otherwise.
- **`clipUrl`** is the looping video, when there is one. Optional; the
  client keeps it but does not play it yet.
- **`failureReason`** is one sentence the person can act on, shown
  under "Failed". Optional, only with `failed`.
- **`personal`** marks the one shown as the profile picture and on the
  leaderboard; the server enforces that at most one is ever true, the
  client just reflects it. When an account's first avatar finishes and
  none is personal, make that one personal: nobody should have to find
  a button before their face shows up.

The client re-reads this route on its own every 15 seconds while any
avatar is `training` and the gallery is open, and once when the gallery
opens. Keep it cheap: it is the whole of the training "push" for now.

The same `previewUrl`, for whichever avatar is personal, belongs on the
signed-in creator's own row in `/v1/standings` as `avatarUrl` — that is
the one place someone else's face is worth the request, because it is
hosted by you rather than carried in bytes on every viewer's device.

### `/v1/standings`

```json
[{ "rank": 1, "name": "Marisol Vega", "earnings": 11727.62,
   "movement": 0, "tier": "gold", "isYou": false }]
```

`rank`, `name` and `earnings` are required. `tier` is one of `bronze`,
`silver`, `gold`, `platinum`, or null. Exactly one row should carry
`"isYou": true`; the app falls back to the last row if none does.
`avatarUrl` only makes sense on that one row: showing it is worth a
network image because it is your own account's, hosted by you; the rest
of the board still goes by initials rather than asking the client to
carry or fetch a stranger's photo.

### `/v1/vault` and `/v1/ecovault`

Same row shape. `/v1/vault` is what this person made; `/v1/ecovault` is
the gallery everyone browses.

```json
[{ "id": "e-1", "title": "Tide clock, slow dissolve", "kind": "video",
   "prompt": "A tide clock on a weathered wall…",
   "model": "HeyGen · video v2", "createdAt": "2026-09-17T08:12:00Z",
   "credits": 18, "aspect": 1.777, "published": true,
   "durationSeconds": 12, "width": 1920, "height": 1080,
   "byHandle": "marisol", "byName": "Marisol Vega", "saved": true }]
```

Three fields carry the gallery:

- **`byHandle` / `byName` — who made it.** Omit both on `/v1/vault`: a
  row with no author is the person's own, and the client gates rename,
  publish and delete on exactly that. Send them on every `/v1/ecovault`
  row, **including the viewer's own pieces**, or send neither and the
  client will treat that row as the viewer's own work.
- **`saved` — whether *this viewer* has hearted it.** It is a fact about
  the person asking, not about the piece, so the same row comes back
  `true` for one account and `false` for another. Default false.

`/v1/ecovault` includes the viewer's own published pieces, so the gallery
reads the same for everyone. Their `saved` is ignored: your own work is
in your vault because you made it, not because you hearted it.

Three more fields carry the file itself (added 23 Sept 2026):

| field | type | meaning |
|---|---|---|
| `mediaType` | `image` \| `video` \| `audio` \| `document` | The file's real type. `kind` stays `image`/`video` so older clients keep parsing; audio used to arrive as `image`. Missing means `kind`. |
| `mediaUrl` | string or null | The full file. Null for a text-only piece (a deck or a page). |
| `thumbnailUrl` | string or null | A ~30 KB WebP, 480 wide; a video's first frame. Null for audio and documents. |

Both URLs are on the app's own origin, so CanvasKit can draw them on the
web without CORS, and **need no auth header**: they are public by an
unguessable name. Video answers HTTP Range (206), so the player can seek
and iOS Safari plays it. With no `thumbnailUrl` the client draws the
piece's seeded art, with a symbol for audio and documents.

### Hearting

| Method | Path | Returns |
|---|---|---|
| POST | `/v1/ecovault/{id}/save` | the row, `saved: true` |
| DELETE | `/v1/ecovault/{id}/save` | the row, `saved: false` |

A heart is a bookmark held against the viewer. It copies nothing, it
does not change the author's piece, and it must not move credits,
earnings or trophy progress to the person who hearted it. The client
shows the heart immediately and puts it back if you refuse, so a 4xx is
a safe answer.

Both return the full row so the client can take the server's word for
the final state rather than assuming its own guess was right.

### `/v1/trophies`

The trophy **catalogue lives in the client** — eighteen trophies with their
names, artwork and tiers, which the server has no copy of. The server says
only how far along each one is:

```json
[{ "id": "out_loud", "earnedOn": "2026-09-01T00:00:00Z",
   "progress": 1.0, "progressLabel": "1 of 1", "memberPercent": 44 }]
```

Ids the client does not know are ignored; ids it knows but you omit keep
their seeded values. `earnedOn` null or absent means not earned.

### `/v1/vault`

```json
[{ "id": "v1", "title": "Rooftop loop, take 3", "kind": "video",
   "prompt": "...", "model": "HeyGen · video v2",
   "createdAt": "2026-09-16T21:14:00Z", "credits": 14, "aspect": 0.5625,
   "published": false, "durationSeconds": 6, "width": 1080, "height": 1920 }]
```

`kind` is `image` or `video`. `aspect` is width ÷ height and drives the
masonry, so send it even when width and height are present.

### `/v1/notes`

```json
[{ "id": "n1", "title": "Standup, Tuesday", "body": "...",
   "editedAt": "2026-09-17T10:00:00Z" }]
```

### `/v1/trophies`

**Send a row only for a trophy this account has progress on.** The
catalogue — which trophies exist, their names, glyphs and tiers — is the
client's, because it is artwork. Everything about *how far along someone
is* is yours, and the client zeroes every trophy before applying what you
send. A trophy you say nothing about is shown unearned, at zero.

```json
[{ "id": "first_light", "earnedOn": "2026-09-01T00:00:00Z",
   "progress": 1.0, "progressLabel": "1 of 1", "memberPercent": 91 }]
```

`progress` is 0 to 1 and drives the bar. `progressLabel` is the short line
under it — "3 of 10", "Best #13", whatever reads right for that trophy.
Send it in ordinary sentence case: the client decides how to set it, and
a string that arrives shouted cannot be reliably unshouted ("Friday" would
come back as "friday").
`memberPercent` is how many members hold it; omit it or send 0 and the
rarity is simply not shown rather than shown as 0%.

Trophy ids are snake_case and fixed by the client:
`first_light`, `out_loud`, `on_the_board`, `first_dollar`, `sound_check`,
`face_time`, `prolific`, `quadruple_threat` and the rest — the full list
is `Seed.trophies` in `lib/data/seed.dart`.

### `/v1/connections`

Same split. The client carries the catalogue of services SHIFT can talk
to; you say which ones **this account has authorised**.

```json
[{ "name": "Gmail", "live": true }]
```

A name the client already knows is marked live. A name it does not know
is added to the list, so you can light up a connector the client has
never heard of without a client release. Anything you do not name reads
as not connected.

### `/v1/agents/runs` and `/v1/agents/jobs`

```json
[{ "id": "r1", "title": "Scan conditional imports", "detail": "...",
   "status": "failed", "checksPassed": false, "diff": "+128 -14",
   "scope": "shiftai/shift" }]
```

`status` is one of `working`, `needsYou`, `inReview`, `done`, `failed`.
`scope` is the repository a run belongs to, or the folder a job runs in;
the client filters both lists by the scope showing, so a row without one
is treated as belonging to the default scope.

Three writes go with these:

| Method | Path | Body | Returns |
|---|---|---|---|
| POST | `/v1/agents/runs` | `{ "prompt": "...", "scope": "..." }` | the new run |
| POST | `/v1/agents/jobs` | `{ "prompt": "...", "scope": "..." }` | the new job |
| POST | `/v1/agents/runs/{id}/rerun` | — | the run, back to `working` |

Each answers with a single row in the shape above. The client shows the
row optimistically and puts the list back if the call is refused, so a
4xx is a safe answer rather than something to avoid.

### `/v1/designs`

```json
[{ "id": "d1", "title": "Palette reference sheet", "versions": 2,
   "kindLabel": "Page" }]
```

`kindLabel` shows on the thumbnail — `Page`, `Deck`, `Brand`, in sentence
case like every other display string.

### `/v1/connections`

```json
[{ "name": "Gmail", "live": true }]
```

### `/v1/week`

```json
{ "pool": 53497, "payoutLine": "Pools pay Friday" }
```

The week itself is not sent: the client computes it, and the rule is the
Suite's. A week runs **Tuesday 10 PM Central to the next Tuesday 10 PM
Central** (`lib/util/week.dart`). Pools pay on Friday, which is not the
close, so copy should never call Friday the end of the week. No income
claims ("you will earn") in anything the server sends for display.

### `/v1/boards` (the Suite's weekly boards)

Optional: an engine without it, or one that fails it, still loads, and
the Global tab falls back to `/v1/standings`. Answers as the signed-in
member, from the same code as the Suite's `/leaderboard` pages, wrapped
in `{ "data": ... }`. Money is in **cents**, sometimes as a string.

```json
{ "data": {
    "compete": [{ "id": "u1", "display_name": "Rex Wilson",
                  "avatar_url": null, "current_tier": 3,
                  "tier_name": "Gold", "is_me": false, "rank": 1,
                  "combined_cents": "123456" }],
    "crowd": [], "credit_hold": [], "credit_use": [], "club_pools": [],
    "connect_week": [], "projected_week": [], "lifetime": [],
    "my_pool_standings": {}, "credit_weights": { "held": 0, "use": 0 },
    "connect_window": { "start": null, "end": null } } }
```

| key | label in the app (the Suite's) | value field |
|---|---|---|
| `compete` | CompetePay | `combined_cents` |
| `crowd` | Window earnings | `window_earnings_cents` |
| `credit_hold` | Credits held | `credits_held_cents` |
| `credit_use` | Credits used | `credits_used_cents` |
| `club_pools` | Projected club pay | `projected_clubpay_cents` |
| `connect_week` | CoachPay this week | `earned_cents` |
| `projected_week` | Projected this week | `projected_total_cents` |
| `lifetime` | Lifetime earnings | `earned_cents` |

A board with no rows is not shown. `tier_name` colours a row when it
names bronze, silver, gold or platinum; anything else is shown without a
colour. The Suite does not track movement, so these rows never say
"up 2". Not read yet: `my_pool_standings`, `credit_weights`,
`connect_window`, and the `/v1/boards/clubs`, `/projections`, `/what-if`
and `/v1/account` routes.

### `/v1/league`

```json
{ "division": "silver", "regionLabel": "Austin Metro", "promoteCount": 3,
  "relegateCount": 3,
  "rows": [{ "rank": 1, "name": "Jodie Marsh", "earnings": 412.80,
             "movement": 1, "isYou": false }] }
```

A small board — the same row shape as `/v1/standings` — scoped to people
near this account in both **rank and location**, rather than the whole
board. It is a different, smaller competition, not a filtered view of the
global one, so its rows do not need to be a subset of `/v1/standings`'s.

`division` is one of `bronze`, `silver`, `gold`, `platinum`: which rung of
the ladder this cohort is on. `promoteCount` and `relegateCount` are how
many of the top and bottom ranks move divisions when the week closes; the
client colours those rows itself from `rank` and `rows.length`, so send
accurate ranks and nothing else. Exactly one row should carry
`"isYou": true`, same rule as `/v1/standings`.

**Before this account has shared a location, answer `{}`.** An empty
object means "not placed yet," not an error — the client shows a prompt
to turn location on rather than a board. Never answer with
`/v1/standings` in a league's clothing: a global row standing in for a
local one is the same leak as the seeded catalogue standing in for an
account, just on a smaller board.

## Writes

| Method | Path | Body | Returns |
|---|---|---|---|
| GET | `/v1/models` | — | the AIs that can answer |
| POST | `/v1/messages` | `{prompt, private, avatarId?, model?, history}` | the answer, as messages |
| POST | `/v1/polish` | `{prompt}` | `{prompt}` |
| PATCH | `/v1/me` | `{handle}` | the creator |
| PATCH | `/v1/vault/{id}` | `{title}` | the item |
| POST | `/v1/vault/{id}/publish` | — | the item |
| DELETE | `/v1/vault/{id}` | — | — |
| POST | `/v1/notes` | `{title, body}` | the note |
| PATCH | `/v1/notes/{id}` | `{title, body}` | the note |
| DELETE | `/v1/notes/{id}` | — | — |
| POST | `/v1/designs/{id}/duplicate` | — | the new design |
| DELETE | `/v1/designs/{id}` | — | — |
| POST | `/v1/uploads` | multipart, field `file` | `{id}` |
| POST | `/v1/avatars` | `{uploadId, name, consent}` | the avatar, `training` |
| POST | `/v1/avatars/{id}/personal` | — | the avatar, now `personal` |
| DELETE | `/v1/avatars/{id}` | — | — |
| PATCH | `/v1/me/location` | `{lat, lng}` | the league placement |

### `POST /v1/messages`

```json
{ "prompt": "Cut a 20 second vertical promo", "private": false,
  "avatarId": "a1" }
```

`avatarId` is optional and names one of this creator's own avatars —
generate as that likeness. An id that is not theirs, not found, or not
yet `ready` is a `badRequest`, with a sentence for it.

**No `avatarId` means the built-in avatar, `shiftai-default`.** She ships
with the app (`assets/avatars/shiftai-default.jpg`) and is what the Suite
generates as until someone picks one of their own, like HeyGen's stock
presenters. Train her once on the server from the full-size original,
`docs/avatars/shiftai-default-1024.jpg` (AI-generated for ShiftAi, not a
real person, so no likeness consent applies), and use her whenever
`avatarId` is absent or is `"shiftai-default"`. She is never in
`GET /v1/avatars` and never anyone's `personal` avatar or leaderboard
face: those stay the person's own.

Answer with one or more messages, in the order they should appear:

```json
[{ "id": "m1", "author": "shift", "eyebrow": "ShiftAi · Video",
   "body": "Here is the cut...",
   "bullets": ["0:00 to 0:06 — wide shot, no music"],
   "attachment": { "fileName": "promo-vertical-v4.mp4", "kind": "video",
                   "meta": "20S · 1080 × 1920 · 14 CREDITS",
                   "vaultItemId": "v1" } }]
```

`author` is `you` or `shift`. Every field except `id` and `author` is
optional — a message can be prose, bullets, an attachment card, a failure
notice, a question with answers to tap, or any combination.

**How long it may take.** This route gets 3 minutes; every other route
gets 20 s. After 20 s the thread says it is still working and the send
button becomes Stop. Stop closes the connection, so a server that stops
the model call when its caller goes away saves the credits. An answer
that needs longer than 3 minutes should come back at once as "working on
it" and land in the vault when it is done.

**A made file.** `attachment.vaultItemId` names a row that is already in
`GET /v1/vault` when the answer goes. The app re-reads `/v1/vault` when an
answer names a row it does not have yet, so "Open in Vault" finds it.

**Retry and Edit** re-send an earlier question in place: the history
then ends before that question, and the reply being replaced (or, for
an edit, everything after the question) is not in it.

### Writing the answer out as it comes

Optional, and the app works without it. `POST /v1/messages` is sent
with `Accept: text/event-stream, application/json`. Answer JSON as above
and nothing changes. Answer `Content-Type: text/event-stream` instead
and the reply appears word by word, the way Claude's does:

```
event: text
data: {"text": "Harbour light, "}

event: text
data: {"text": "one crossing."}

event: messages
data: [{"id": "m4", "author": "shift", "model": "claude-opus-5-5", "modelName": "Claude Opus 5.5", "body": "Harbour light, one crossing."}]
```

- **`text`** carries the next piece of the reply, not the whole of it so
  far. The app shows them joined, as one reply that grows.
- **`messages`** is the finished answer, exactly the JSON the route
  otherwise returns, choices and attachments included. It replaces what
  was written out. Send it last.
- **`error`** with `{"message": "..."}` ends it as a refusal, and the
  person sees the sentence.
- A stream that ends with no `messages` keeps what was written as the
  reply. A comment line (`: keep-alive`) is ignored, so it can hold a
  quiet connection open; after 3 minutes with nothing, the app gives up.
- Stop closes the connection mid-stream. What was written stays in the
  thread.

### Questions with answers to tap

When a model needs to ask before it goes on, the app draws its answers
as buttons under the reply, the way Claude asks. Tapping one sends its
`label` as the person's next message; typing works too.

```json
[{ "id": "m2", "author": "shift",
   "body": "What should it feel like?",
   "choices": [
     { "label": "Cinematic", "description": "Slow drone shots, golden hour" },
     { "label": "High energy", "description": "Fast cuts on the beat" },
     "Calm"],
   "multiSelect": false }]
```

- `choices` holds up to 8 answers, each `{label, description?}` or a
  plain string. `label` is what gets sent; `description` is only shown.
- `multiSelect: true` lets the person tick several and send them
  together, as "Instagram Reels, TikTok and YouTube".
- `question: { options: [...], multiSelect }` is read too, so the input
  of a tool call like Claude's AskUserQuestion can be passed on as it
  is. The simplest way to get this from any model: give it an
  `ask_user` tool with that schema, and when it calls it, answer with
  the tool's input as this message and stop the turn there.
- Only the newest reply shows buttons. On the next message the
  offered answers come back in `history` inside that reply's `body`,
  one `- label: description` line each, so "the second one" means
  something to whichever model answers next.
- Without `choices`, a reply that ends in a question with 2 to 8 short
  listed options right against it ("1. …", "- …", "A) …") gets buttons
  anyway, and those lines move from the text into the buttons. That
  covers models writing their questions out; `choices` is still the
  reliable way.

### Several AIs in one conversation

The Suite can be answered by any AI the server has connected, and one
conversation can move between them. Each one has to read everything said
so far, the others' replies included, and carry on from it **as though
they were one model**.

`GET /v1/models` lists who can answer, in the order the picker shows them:

```json
[{ "id": "claude-opus-5-5", "name": "Claude Opus 5.5",
   "provider": "Anthropic", "default": true },
 { "id": "gpt-x", "name": "…", "provider": "…" }]
```

Optional: without it (404 or an error) the app shows no picker and sends
no `model`. With more than one, the composer shows "Answering: <name>";
`Auto` sends no `model` and the server picks, usually the `default` one.

`POST /v1/messages` gains two fields:

```json
{ "prompt": "Now make it shorter",
  "model": "claude-opus-5-5",
  "history": [
    { "role": "user", "body": "Write a caption for the ferry clip" },
    { "role": "assistant", "model": "gpt-x",
      "body": "Morning light on the harbour, one crossing at a time." }
  ] }
```

- **`model`**: which AI answers. Missing means the server's choice. An id
  the server does not have is a `badRequest`, with a sentence.
- **`history`**: the whole conversation before `prompt`, oldest first. The
  app sends it with every message, so the server does not have to keep a
  thread to make this work, and a private chat is never stored anywhere.

What the server must do with `history`, which is the whole point:

1. Give the chosen model **every** turn, in order, then `prompt` as the
   newest user turn.
2. Send each earlier reply as the **assistant's own** turn (role
   `assistant` in whatever form that provider takes), **whichever model
   wrote it**. Do not relabel another model's reply as a user message,
   and do not write "another AI said" into the text. That is what makes a
   model read the earlier answers as its own and carry on from them in
   one voice. The turn's `model` is for your records only; leave it out
   of what the model sees.
3. Give every model the same system instructions for the Suite, so the
   voice does not change when the model does.
4. Reply-side lists and attachments are already folded into `body` as
   text (`- item`, `[Attached: file.mp4]`), so a model sees them too.
   Failure notices are the app's, not a reply, and are never sent.

Every answer message says who wrote it:

```json
[{ "id": "m4", "author": "shift", "model": "claude-opus-5-5",
   "modelName": "Claude Opus 5.5", "body": "Harbour light, one crossing." }]
```

The app labels the reply with `modelName`, and sends `model` back in the
next `history`. `tool/mock_engine.py` implements all of this, with two
stand-in models; its reply quotes the last answer it was given, so you
can see a model reading another's reply.

**`private: true` means do not retain the exchange.** The client already
keeps private threads out of its own storage; honouring this server-side is
the other half of that promise, and the claim is made to the person in the
composer's hint text.


#### Best fit: one model per message, the right one

One model answers each message. With nothing picked by hand, the app
chooses it (**Best fit**) and sends its id as `model`:

- A message asking for a video, an image or audio goes to a model whose
  `bestFor` includes `video`, `image` or `audio`; code, research and
  writing likewise. "Write a caption for the clip" is writing, not video:
  a piece of text is writing whatever it is for.
- Anything no specialist covers ("make it shorter", a plain question)
  stays with the model that answered last if that is a general model, and
  otherwise goes to the `default` one.
- **A chat model never answers a request for an image, a video or
  audio.** Those go only to a model whose `bestFor` names them, even
  over a chat model picked by hand. With none connected, the app sends
  nothing and says "No image model is connected yet. Nothing was sent,
  and nothing was charged." So list image, video and audio models with
  `bestFor` (or names that say what they are), or those requests go
  unanswered.
- People can still pick one model by hand, and it then answers
  everything it can make.
- With no models listed at all the server chooses who answers words,
  but the app does not send it a request for an image, a video or audio:
  it cannot tell which of the server's models make them, and left to
  choose, the preview answered "generate an image of Miami" with its
  chat model ("I can't generate images"). List those models with
  `bestFor` and they are sent.

Say what each model is for in `/v1/models`:

```json
[{ "id": "claude-opus-5-5", "name": "Claude Opus 5.5", "provider": "Anthropic",
   "default": true },
 { "id": "veo-3", "name": "Veo 3", "provider": "Google", "bestFor": ["video"] },
 { "id": "flux-pro", "name": "Flux Pro", "provider": "BFL", "bestFor": ["image"] }]
```

`bestFor` takes `image`, `video`, `audio`, `code`, `writing`, `research`.
Without it the app guesses from the name (Sora, Veo, Runway, Kling → video;
DALL·E, Imagen, Flux, Midjourney, Ideogram → image; Suno, Udio, Eleven →
audio), and a model it cannot place is general. With no models listed at
all, `model` is left out and the server picks, for words only (above).

### Saved chats: `/v1/threads`

Every chat that is not private is saved as it happens, so it can be
opened again from Recents in the drawer. The device keeps a copy for the
signed-in account; these routes keep one on the server so a chat follows
the account to another device.

| Method | Path | Body | Returns |
|---|---|---|---|
| GET | `/v1/threads` | — | this account's chats, newest first |
| PUT | `/v1/threads/{id}` | the chat | the chat |
| DELETE | `/v1/threads/{id}` | — | — |

```json
{ "id": "chat-1727178000000000", "title": "Plan a shoot at the ferry terminal",
  "updatedAt": "2026-09-24T14:20:00Z",
  "messages": [
    { "id": "you-1", "author": "you", "body": "Plan a shoot at the ferry terminal" },
    { "id": "m1", "author": "shift", "body": "…", "model": "claude-opus-5-5",
      "modelName": "Claude Opus 5.5" }] }
```

- The id is the client's; `PUT` creates or replaces. It is sent after
  each message and each answer, with the whole chat.
- **Never store a message sent with `private: true`.** The client never
  saves a private chat; the server must not either.
- Optional: a 404 on any of these and the app keeps chats on the device
  only, without an error. The app merges the server's list with the
  device's by id, keeping the newer copy of each.
- The Suite's own `chat/threads` routes can back these.

### `POST /v1/polish`

The composer's sparkle, "Polish my prompt". Body `{ "prompt": "make a
poster" }`; answer `{ "prompt": "<the fuller brief>" }`. The client puts
the answer back in the bar with an Undo; it never sends it on its own.

- **No polisher yet? Answer 404.** The client then asks the connected
  AI itself, through `POST /v1/messages`: one `private: true` message
  with no history, an instruction to rewrite the prompt and reply with
  the rewrite only, and the prompt. The reply's `body` is the rewrite (a
  "Here is the polished prompt:" preamble and quotes are taken off). An
  answer here that is the prompt unchanged, or has no rewrite in it, is
  treated the same way. Only with no server at all does the app write
  its own template brief.
- **Where the rewrite goes.** `{ "prompt": "..." }` is the shape. The
  client also reads `polished`, `polishedPrompt`, `result` or `text`,
  ahead of `prompt`, and looks inside a `data` envelope, so relaying the
  Suite's `image/polish-prompt` answer as it is works either way.
- **A refusal is shown as one.** Out of credits, moderation, a provider
  down: answer the usual error shape and the person sees the `message`,
  with what they typed left alone.
- Plain text only. If the Suite's polisher is `image/polish-prompt`,
  this route can wrap it; the studio relay's shape is not one the client
  reads.

### `PATCH /v1/me`

```json
{ "handle": "shiftai2" }
```

Changes the signed-in creator's username. Answer with the same shape as
`GET /v1/me`, handle included, so the client has the settled value —
whether that is what was sent or a server-side normalisation of it.
A handle already taken is a `badRequest`, with a sentence for it in
`message`.

### `POST /v1/avatars`

```json
{ "uploadId": "u1", "name": "Studio lighting", "consent": true }
```

`uploadId` is the id `POST /v1/uploads` handed back for a photo of this
creator: one image, `image/png`, `image/jpeg` or `image/webp` (and HEIC
from an iPhone), at least 256 px on the short side and at most 2048 px on
the long side. The multipart part's content type always matches its bytes.

`consent: true` means the person ticked "This photo is of me, and I agree
to ShiftAi making an animated avatar of my likeness from it". The client
cannot send this route without it. Record it wherever the Suite records
likeness consent (its `likeness-consent` studio route), and refuse a
request without it as a `badRequest`.

Kick off training with HeyGen (or whatever renders it) and answer
immediately with the new avatar at `status: "training"` — this does not
wait for the render. `GET /v1/avatars` is how the client learns it
finished; see above for how often it asks.

`POST /v1/avatars/{id}/personal` takes no body and answers with that
avatar at `personal: true`. Only a `ready` avatar can be personal; refuse
the others as a `badRequest`. Every other avatar this creator has should
come back `personal: false` on the next read — the server owns "exactly
one," the client only asks for a specific one to be it.

`DELETE /v1/avatars/{id}` removes one. Deleting the personal avatar is
a decision for you to make (fall back to initials, or refuse it) —
either is a valid answer, the client handles both.

### `PATCH /v1/me/location`

```json
{ "lat": 30.2672, "lng": -97.7431 }
```

Resolve this into whatever region bucket you use for matching — a metro
area is granular enough, and the client only ever asks for this much:
there is no continuous tracking, no background updates, just a fix taken
when the person opens the local board or asks to update it. Answer with
the same shape as `GET /v1/league`.

Whether a new location moves the account into a different cohort right
away or only once the current week closes is your call and is invisible
to the client either way — it draws whatever `division` and `rows` come
back.

### Writes and the UI

Every write is applied on screen first and rolled back if you refuse it,
so a 4xx is not just logged — the row visibly returns to what it was and
the reason surfaces. Two exceptions, which wait for your answer because
the id you assign is what later edits are addressed to:

- `POST /v1/notes` — the row appears only once you have given it an id.
- `POST /v1/designs/{id}/duplicate` — likewise.
- `POST /v1/avatars` — likewise; there is also nothing sensible to show
  optimistically for a render that has not started.

## Errors

Any non-2xx is turned into one exception with a `kind` the UI can act on:

| Status | kind | Retryable |
|---|---|---|
| — (no route to host) | `offline` | yes |
| — (timed out: 20 s, or 3 min for `/v1/messages`) | `timeout` | yes |
| 401 | `unauthorised` | no |
| 403 | `forbidden` | no |
| 404 | `notFound` | no |
| other 4xx | `badRequest` | no |
| 5xx | `server` | yes |
| 2xx with an unreadable body | `malformed` | no |

Put a human sentence in `message`, `error` or `detail` and the person sees
it. Send nothing useful and they get a generic line instead — so this is
worth filling in.

## What must never come from the client

Three screens are the engine's alone, and the client now enforces it:

- **The vault**, **EcoVault**, **the trophy shelf** and **the
  leaderboard**. With a base
  URL configured, an engine that does not answer leaves these empty and
  says so. They never fall back to the built-in catalogue — which is one
  person's sample data, and showing it to somebody else as their own
  vault and earnings is the failure this rule exists to prevent.
- **The cache is keyed to an account.** The client writes the signed-in
  email into its local blob and refuses to read that blob back for a
  different account. Signing out empties it.

So a 5xx from you is safe. It shows an empty screen and an error, which
is honest. There is no mode in which stale or borrowed data appears.

## Auth

This is the part that blocks a store submission, so it is specified here
in full rather than left to be agreed later. Four routes. None of them
carry a bearer token except `DELETE /v1/me`.

### `POST /v1/auth/sign-in`

```json
{ "email": "demo@shiftai.club", "password": "..." }
```

Answers 200 with:

```json
{ "accessToken": "...", "refreshToken": "...", "expiresIn": 3600,
  "user": { "handle": "shiftai", "name": "ShiftAi",
            "email": "demo@shiftai.club" } }
```

`expiresIn` is seconds. `user` is the same shape as `GET /v1/me`, so the
client can draw the account row without a second call.

Wrong credentials are **401 with a message the person can read** — "That
email and password do not match." The client shows `message` verbatim, so
do not return a stack trace or a bare `"Unauthorized"`. Do not
distinguish "no such account" from "wrong password"; that tells an
attacker which emails exist.

### `POST /v1/auth/refresh`

```json
{ "refreshToken": "..." }
```

Same 200 body as sign-in. A refresh token that is expired, revoked or
already used answers 401, and the client signs the person out rather than
retrying.

### `POST /v1/auth/sign-out`

```json
{ "refreshToken": "..." }
```

204. Revoke the refresh token. The client clears its own copy either way,
so a failure here is not fatal — but an un-revoked token is.

### `DELETE /v1/me`

204. **Apple requires this** — an app that lets people create an account
must let them delete it from inside the app (App Review Guideline
5.1.1(v)), and a submission without it is rejected. Deleting takes the
account, the vault, the notes and the designs with it. If deletion is
queued rather than immediate, answer 202 and put the date it completes in
`message`.

### How the client handles 401

On any 401 from a normal call, the client refreshes **once** and replays
the request. If the refresh also 401s, it drops both tokens and returns
to the sign-in screen. It never loops. So: keep refresh tokens valid long
enough that a person who opens the app weekly is not signed out — 30 days
is the assumption.

### Where the tokens live

Not in shared preferences. iOS Keychain and Android Keystore, via
`flutter_secure_storage`. Nothing about auth is written to the
`shift.app.v1` blob.

## Not built yet

These are deliberate gaps, not oversights. Each one needs a decision from
you before it can be written:

- **Pagination.** Every list is assumed to arrive whole. A vault of
  thousands needs a cursor, and the masonry needs to learn to page.
- **Realtime.** Agent runs and the leaderboard are pull-only. They would
  want a socket or SSE to feel live.
- **Upload progress.** `POST /v1/uploads` is one shot with no progress
  reporting and no resume.
- **Avatar training status is poll-only.** The gallery re-reads
  `/v1/avatars` every 15 seconds while one is training; leave the
  gallery and it waits until you come back. Realtime, above, would
  replace the poll if it gets built.
- **Which provider renders an avatar.** This document assumes HeyGen
  because that is the plan, but nothing in the contract names it — the
  client only ever sees `training` / `ready` / `failed` and a URL.
