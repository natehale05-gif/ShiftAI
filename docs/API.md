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
   "previewUrl": "https://cdn.example.com/avatars/a1.mp4" },
 { "id": "a2", "name": "Studio lighting", "status": "training",
   "personal": false }]
```

`id` and `name` are required. `status` is one of `training`, `ready` or
`failed`, and falls back to `training` if it is anything else — a status
the client does not recognise should not read as ready. `personal` marks
the one shown as the profile picture and on the leaderboard; the server
is the one enforcing that exactly one is ever true, the client just
reflects it. `previewUrl` is the still or looping clip HeyGen rendered;
send it once `status` is `ready`, omit it otherwise.

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
| POST | `/v1/messages` | `{prompt, private, avatarId?}` | the answer, as messages |
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
| POST | `/v1/avatars` | `{uploadId, name}` | the avatar, `training` |
| POST | `/v1/avatars/{id}/personal` | — | the avatar, now `personal` |
| DELETE | `/v1/avatars/{id}` | — | — |
| PATCH | `/v1/me/location` | `{lat, lng}` | the league placement |

### `POST /v1/messages`

```json
{ "prompt": "Cut a 20 second vertical promo", "private": false,
  "avatarId": "a1" }
```

`avatarId` is optional and names one of this creator's own avatars —
generate as that likeness rather than in whatever voice the engine
answers in by default. An id that is not theirs, not found, or not yet
`ready` is a `badRequest`, with a sentence for it.

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
notice, or any combination.

**`private: true` means do not retain the exchange.** The client already
keeps private threads out of its own storage; honouring this server-side is
the other half of that promise, and the claim is made to the person in the
composer's hint text.

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
{ "uploadId": "u1", "name": "Studio lighting" }
```

`uploadId` is the id `POST /v1/uploads` handed back for a photo or clip
of this creator. Kick off training with HeyGen (or whatever renders it)
and answer immediately with the new avatar at `status: "training"` —
this does not wait for the render. `GET /v1/avatars` on a later `load`
or `refresh` is how the client learns it finished; there is no push for
this yet, see "Not built yet".

`POST /v1/avatars/{id}/personal` takes no body and answers with that
avatar at `personal: true`. Every other avatar this creator has should
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
| — (timed out, 20s) | `timeout` | yes |
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
- **Avatar training status is poll-only.** A creator has to reopen or
  refresh to learn a `training` avatar became `ready`; there is no push
  for it. Realtime, above, would cover this too if it gets built.
- **Which provider renders an avatar.** This document assumes HeyGen
  because that is the plan, but nothing in the contract names it — the
  client only ever sees `training` / `ready` / `failed` and a URL.
