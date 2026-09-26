# Server brief, update 1 — what changed since the first brief

Give this to Claude Code after `docs/REX-SERVER-BRIEF.md`. The app side of
everything below is already live on `main`. The full brief in the repo
has all of it merged in; this file is only the difference, so nothing
already done gets redone.

When you are done, run the checker (last section) against the preview
and send Nate its output.

## 1. Files attached in chat: `attachments` on `POST /v1/messages`

The "+" in the chat now uploads each file first (`POST /v1/uploads`,
multipart, field `file`, one file per request, answers `{ "id": "u1" }`).
The upload is given up to 2 minutes. The message then names the files
by id:

```json
{ "prompt": "What is in this photo?",
  "attachments": [{ "uploadId": "u1", "name": "ferry.png",
                    "mimeType": "image/png", "sizeBytes": 48213 }],
  "history": [
    { "role": "user", "body": "Caption this",
      "attachments": [{ "uploadId": "u0", "name": "clip.mp4",
                        "mimeType": "video/mp4" }] },
    { "role": "assistant", "model": "claude-opus-5-5", "body": "..." }
  ] }
```

- Give the model **the files themselves**: an image as an image block, a
  PDF as a document, a text file as its text. For Anthropic's Messages
  API that is an `image` or `document` content block beside the text.
- Turns in `history` carry their own `attachments`. Send those with the
  turn they belong to, so a model that joins mid-conversation can see
  them.
- A prompt can be empty when a file is sent on its own.
- With `private: true`, do not keep the files after the answer.
- An upload id that is not this account's is a 400 with a sentence.

Before this change the app sent only the names, as text in the prompt,
and no model ever saw a file.

## 2. The app waits 3 minutes for `/v1/messages`, and can Stop

- Every other route gets 20 s; `/v1/messages` gets 3 minutes. After 20 s
  the app says "Still working" and the send button becomes Stop.
- **Stop closes the connection.** When the caller goes away, cancel the
  model call and don't charge for it, where the provider allows that
  (listen for the request's close or abort event).
- A render that takes longer than 3 minutes should answer at once with a
  "working on it" message and put the finished file in the vault.

## 3. Streaming (optional, and worth it)

The app sends `Accept: text/event-stream, application/json`. Answer JSON
and nothing changes. Answer `Content-Type: text/event-stream` and the
reply appears word by word:

```
event: text
data: {"text": "Harbour light, "}

event: text
data: {"text": "one crossing."}

event: messages
data: [{"id":"m4","author":"shift","model":"claude-opus-5-5","modelName":"Claude Opus 5.5","body":"Harbour light, one crossing."}]
```

- `text` is the **next piece only**, not everything so far.
- `messages` comes last. It is the finished answer, the exact JSON array
  the route returns without streaming (model, modelName, choices,
  attachment), and it replaces what was streamed.
- `event: error` with `{"message": "..."}` ends it as a refusal the
  person sees.
- For Anthropic, each `content_block_delta` whose delta is text becomes
  one `text` event.
- Image and video models have nothing to stream, so answer them with
  JSON.
- Comment lines (`: keep-alive`) are ignored and can hold a quiet
  connection open.

## 4. EcoVault is a feed: two optional fields on `/v1/ecovault` rows

- `hearts`: how many people have hearted it. Shown as "1,284 hearts".
  Leave it out and no count is shown; the app never guesses one.
- `byAvatarUrl`: the maker's personal avatar still (its `previewUrl`).
  Initials are shown without it.

## 5. `DELETE /v1/me`: how the app reads the answer

- `204`: the account is deleted. The app signs out.
- `202` with `{ "message": "Your account will be deleted on 3 October." }`
  means the deletion is queued. The app shows that sentence and signs
  out.
- `404`: the app says "This server cannot delete accounts yet, so nothing
  was deleted", and the person stays signed in.

## 6. Check your work: `tool/check_engine.py`

It is in the ShiftAI repo and uses only the Python standard library. It
signs in and calls each route the app uses, then prints one line per
check: `ok`, `missing` (404, which the app handles by falling back),
`differs` (a shape the app will not read), or `skipped`.

```bash
python3 tool/check_engine.py https://app.shiftai.club/app-preview/api \
    --email you@shiftai.club --password '...'

# Also send one message and one upload. This spends real credits.
python3 tool/check_engine.py https://app.shiftai.club/app-preview/api \
    --email you@shiftai.club --password '...' --spend
```

It never calls `DELETE /v1/me`, which would delete the account it signed
in with.
