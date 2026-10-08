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

## 5b. A made image has to come with its file

On 6 October "generate an image of a pink flower" reached SHIFT Image,
and the answer came back with `image-94be8963.png` (1024 × 1024) as its
attachment. The chat now draws the picture itself, but it can only draw
a file it can load:

- Put the file on the attachment as `url` (the full image) and, if you
  have one, `thumbnailUrl`. **Or** make sure the vault row named by
  `vaultItemId` is in `GET /v1/vault` by the time you answer, with
  `mediaUrl` (and `thumbnailUrl`) filled in. The app reads the vault right
  after the answer for exactly this.
- The URL has to load **with no Authorization header** (public by an
  unguessable name, as `docs/API.md` says for vault media).
- If the web app is ever served from a different origin from the files,
  send `Access-Control-Allow-Origin` on them; the web app cannot draw a
  cross-origin image without it.

With none of those, the chat shows the file name and "Open in Vault", and
nothing to look at, which is what it showed on 6 October.

`python3 tool/check_engine.py ... --image` makes one image through the
first model with `bestFor: ["image"]` and checks each of these.

## 5c. Editing a picture in the chat

Under each made picture the chat now has **Edit image**, **Share** and
**Open in Vault**. An edit, whether picked with Edit image or written
straight after a picture ("make the petals purple"), goes to the model
that made it, with the picture as an attachment **by vault reference**:

```json
"attachments": [{ "vaultItemId": "v1", "name": "image-94be8963.png",
                  "mimeType": "image/png", "url": "https://..." }]
```

- Look the file up by `vaultItemId` (this account's vault only), or
  fetch `url`, and give it to the image model as the image to edit
  (image-to-image / an edit endpoint), with `prompt` as the instruction.
- Answer like any made image: a new vault row, an attachment naming it.
- Assistant turns in `history` that made a picture carry it the same
  way. Pass it to whichever model answers, so a chat model asked "what
  flower is this?" can see it.

## 5d. Edits are drawing a new picture instead of changing the one sent

On 7 October, on the preview: "generate an image of a pink flower" made
`image-67b55903.png`. Then "make one of the petals blue" went to SHIFT
Image with that picture attached, exactly as in 5c:

```json
{ "prompt": "make one of the petals blue", "model": "<SHIFT Image's id>",
  "attachments": [{ "vaultItemId": "<its row>", "name": "image-67b55903.png",
                    "mimeType": "image/png", "url": "https://..." }],
  "history": [ ..., { "role": "assistant", "model": "<SHIFT Image's id>",
                      "attachments": [{ "vaultItemId": "<its row>", ... }] } ] }
```

It came back as a **different flower** (white petals, one blue), so the
model was given the words and not the picture. To fix:

- When the model makes images and `attachments` has an image (by
  `vaultItemId`, looked up in this account's vault, or by `url`), call
  the provider's **edit / image-to-image** route with that image and
  `prompt` as the instruction, not its text-to-image route. Which route
  depends on what SHIFT Image runs on, for example:
  - OpenAI `gpt-image-1`: `POST /v1/images/edits` with the image.
  - Gemini image models: the image as an `inlineData` part beside the
    text in `generateContent`.
  - Flux: a Kontext model with the image as its input image.
  - Anything on Replicate or fal: the model's image input
    (`image` / `image_url` / `input_image`).
- If the provider has no way to edit, say so in the answer
  (`"body": "SHIFT Image can't edit pictures yet"`) rather than drawing a
  new one: a new picture labelled as the edit reads as the edit having
  gone wrong.
- Answer as for any made image: a **new** vault row, and an attachment
  naming it, plus **`"editedFrom": "<the vaultItemId you were sent>"`**
  on that attachment. That is how the checker (and later the app) can
  tell an edit from a fresh picture.

Check it with `--edit` (below): it makes a picture, asks for exactly
this edit, and says `differs` until the answer carries `editedFrom`. It
prints both links; look at them, since only a person (or you, reading the
two images) can tell whether the petal changed on the same flower.

## 5e. "Build me a website" should come back as the page, not a brief

On 8 October, "put this into a website about pink flowers" went to
Claude Sonnet 5, which asked two questions with buttons (good) and then
answered "Here's a brief for your romantic pink flower shop site. Use
this as a blueprint…": a description of a site, not a site.

The chat now shows a web page in a reply as the page itself: a live
preview in the thread, full screen on a tap (links and buttons work),
Copy code and Download. It runs sandboxed (scripts only, no access to
the app). For that, the model has to send the page:

- When someone asks to build, make or design a website, landing page or
  web page, the answer contains **one complete HTML document** in a
  fenced block marked `html`:

  ````
  Here is your site.

  ```html
  <!doctype html>
  <html> ... </html>
  ```
  ````

- Everything in the one file: CSS in `<style>`, any JS in `<script>`.
  Images by `https://` URL (a picture made in the chat has one: its
  vault `mediaUrl`) or `data:` URI. No other local files: there is
  nowhere for them to come from.
- Asking a question or two first is fine; the final answer is the page.
  If the Suite's chat system prompt tells the model to write briefs or
  blueprints for the user to build elsewhere, that is what to change.
- Streaming works: while the block is open the thread says "Building
  the page… N lines"; the preview appears when the closing fence lands.

`tool/mock_engine.py` answers "build me a website" this way, so you can
see it in the app against the mock.

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

Add `--image` to make one image and check the chat can show it
(section 5b), and `--edit` to then edit it the way the chat does
(section 5d). It never calls `DELETE /v1/me`, which would delete the
account it signed in with.
