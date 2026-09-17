# ShiftAI :: Supabase key server setup

This backend holds AI provider API keys so the ShiftAI app never ships one.
Keys are encrypted in Supabase Vault, are unreadable by any client role, and are
attached to upstream requests inside an edge function.

## Architecture

```
ShiftAI app ──(user JWT, anon key)──▶ edge function ──(service role)──▶ Vault
                                          │                              │
                                          │◀──── decrypted key ──────────┘
                                          ▼
                                    OpenAI / Anthropic / ...
```

Two kinds of key are supported by the same schema:

| Scope      | `owner_id` | Who can write it | Used when                                     |
|------------|------------|------------------|-----------------------------------------------|
| `user`     | a user id  | that user        | bring-your-own-key — billed to the user       |
| `platform` | `NULL`     | service role only| ShiftAI's own key, used as fallback for anyone |

`get_active_provider_key` prefers a user's own key and falls back to the
platform key, so you can run either model or both without a schema change.

## 1. Create the project

The Supabase MCP connector was not authorized when this code was generated, so
the project has to be created once by hand (or by re-running this task with the
connector connected):

```bash
# https://supabase.com/dashboard → New project. Then, from the repo root:
npm install -g supabase            # or: brew install supabase/tap/supabase
supabase login
supabase link --project-ref <your-project-ref>
```

Record the **project ref**, **anon key**, and **service role key** from
Project Settings → API.

## 2. Apply the schema

```bash
supabase db push        # applies supabase/migrations/* to the linked project
```

Verify from the SQL editor:

```sql
select id, display_name from public.ai_providers;
-- openai, anthropic, google, groq, openrouter
```

## 3. Deploy the edge functions

```bash
supabase functions deploy keys
supabase functions deploy ai-proxy

# optional: lock the functions to your own origins
supabase secrets set SHIFTAI_ALLOWED_ORIGINS="https://shiftai.app,http://localhost:3000"
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are
injected by the platform — do not set them yourself.

## 4. Load a platform key (optional)

Run this in the SQL editor, where the statement never leaves Supabase:

```sql
select public.store_provider_key('openai', 'sk-...your key...', 'default', null);
```

Or over HTTP with the service role key, from a trusted shell only:

```bash
curl -sX POST "https://<ref>.supabase.co/functions/v1/keys" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "content-type: application/json" \
  -d '{"provider":"openai","secret":"sk-...","scope":"platform"}'
```

## 4b. Import keys from an existing .env

If ShiftAI's provider keys currently live in a `.env.local`, load them as
platform keys in one pass:

```bash
node scripts/import-env-keys.mjs .env.local              # prints a plan
SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
  node scripts/import-env-keys.mjs .env.local --confirm  # stores them
```

The script prints only the last four characters of any value, skips empty vars,
and refuses non-AI credentials by name — Stripe keys, session and JWT secrets,
and database URLs do not belong in this vault. It writes straight to
`store_provider_key`, so it needs the migrations applied but not the edge
functions deployed; that also means it **skips the pre-storage verification**
the `keys` function does, so run `scripts/smoke-test.sh` afterwards.

Once imported, delete the provider keys from `.env.local` so there is one home
for them rather than two that can drift.

> **Any key that has been pasted into a chat, a ticket, or a shared file is
> burned.** Rotate it at the provider first, then import the new value.

## 5. Use it from the app

See `examples/client-usage.ts`. In short:

```ts
// store a key (plaintext leaves the device exactly once, over TLS)
await supabase.functions.invoke("keys", {
  body: { provider: "anthropic", secret: userTypedKey },
});

// call the model — no key in the app at any point
const { data } = await supabase.functions.invoke("ai-proxy", {
  body: {
    provider: "anthropic",
    model: "claude-sonnet-4-5",
    payload: { max_tokens: 1024, messages: [{ role: "user", content: "hi" }] },
  },
});
```

## Mirroring ShiftAI users into Supabase Auth

`owner_id` and `subject_id` are foreign keys into `auth.users` and RLS keys off
`auth.uid()`, but ShiftAI's users live in its own Postgres behind its own
`JWT_SECRET`. Mirroring bridges the two: each app user gets a Supabase Auth
user, and `external_user_map` records the correspondence. Nothing requires the
two systems to agree on an id.

### Mirror the users

```bash
npm install
SOURCE_DATABASE_URL=postgresql://...        \
SUPABASE_URL=https://<ref>.supabase.co      \
SUPABASE_SERVICE_ROLE_KEY=<service-role-key> \
  node scripts/sync-users.mjs --table users --id-column id --email-column email
```

It reports what it would do; add `--confirm` to create the accounts. Re-running
is safe — mapped users are skipped, and a user created in Auth whose mapping row
never landed is re-linked rather than duplicated. Run it again after a batch of
signups, or on a schedule.

Mirrored accounts have no password. ShiftAI stays the authority on identity.

### Issue sessions

Supabase never sees a ShiftAI password, so the ShiftAI server mints the session
itself: a JWT signed with the project's JWT secret whose `sub` is the *mirrored*
Supabase user id. Postgres resolves `auth.uid()` from it and every policy
applies unchanged. `examples/mint-supabase-jwt.ts` is the whole flow — resolve
the external id, mint, call the proxy.

The secret is under **Project Settings → API → JWT Settings** (the "legacy JWT
secret" on projects using asymmetric signing keys). Treat it like the service
role key: server-side only, never in the app bundle.

Claims must match what Supabase issues — `role` and `aud` both `authenticated`,
`sub` the user id, HS256 — or the API gateway rejects the request before RLS
ever runs.

### Ordering

Mirror a user *before* their first AI request. A token whose `sub` is not a real
`auth.users` row fails at `auth.getUser()` in the proxy, which reads as a 401.
If ShiftAI creates users continuously, call the sync on signup rather than
relying on a nightly batch.

## Calling the media providers

ElevenLabs, HeyGen, Replicate, fal.ai, Flux, Runway and Luma are not
chat-shaped: they are submit-then-poll, and some return a file rather than JSON.
They have no `chat_path`, so the caller names the endpoint and the method.

Submit, then poll:

```ts
// POST returns an id
const submit = await supabase.functions.invoke("ai-proxy", {
  body: {
    provider: "replicate",
    path: "/v1/predictions",
    payload: { version: "<model-version>", input: { prompt: "a cat" } },
  },
});

// GET polls it
const poll = await supabase.functions.invoke("ai-proxy", {
  body: { provider: "replicate", method: "GET", path: `/v1/predictions/${submit.data.id}` },
});
```

Binary responses (ElevenLabs speech, a rendered video) stream straight through
with their original `content-type` and `content-disposition`, so fetch them
directly rather than through `functions.invoke`, which assumes JSON:

```ts
const res = await fetch(`${SUPABASE_URL}/functions/v1/ai-proxy`, {
  method: "POST",
  headers: { Authorization: `Bearer ${accessToken}`, apikey: ANON_KEY,
             "content-type": "application/json" },
  body: JSON.stringify({
    provider: "elevenlabs",
    path: "/v1/text-to-speech/<voice_id>",
    payload: { text: "hello", model_id: "eleven_multilingual_v2" },
  }),
});
const audio = await res.blob();
```

Provider specifics worth knowing:

| Provider | Base | Auth header | Notes |
|---|---|---|---|
| ElevenLabs | `api.elevenlabs.io` | `xi-api-key` | returns audio; verify via `/v1/user/subscription` |
| HeyGen | `api.heygen.com` | `X-Api-Key` | v2 endpoints; quota at `/v2/user/remaining_quota` |
| Replicate | `api.replicate.com` | `Authorization: Bearer` | the old `Token` scheme is superseded |
| fal.ai | `queue.fal.run` | `Authorization: Key` | poll `/{model}/requests/{id}/status` |
| Flux (BFL) | `api.bfl.ai` | `x-key` | follow the returned `polling_url`, don't rebuild it |
| Runway | `api.dev.runwayml.com` | `Authorization: Bearer` | requires the dated `X-Runway-Version` header |
| Luma | `api.lumalabs.ai` | `Authorization: Bearer` | everything under `/dream-machine/v1` |

**Media spend is bounded by request limits, not the token cap** — these
providers report no token usage, so `platform_tokens_per_day` does not
constrain them. Use `platform_requests_per_day` for that, and note a video
render costs far more than a chat completion at the same request count.

## Security properties

- **Plaintext is write-only from the client.** `my_ai_keys` and the column
  grants on `ai_provider_keys` exclude `secret_id`; `get_active_provider_key`
  is revoked from `anon` and `authenticated` and granted to `service_role` only.
- **RLS is on for every table**, with `select`-own policies and no client-facing
  `insert`/`update`/`delete` policies at all — writes go through SECURITY
  DEFINER functions that keep the vault secret and metadata row in sync.
- **Platform keys are invisible to clients.** No policy matches `owner_id is null`.
- **Keys are verified before storage** with a cheap authenticated GET, so a
  typo fails at setup rather than mid-conversation.
- **Rotation keeps history.** Re-storing the same `(provider, label)` updates the
  vault secret in place, so `ai_usage_events` stays attached.

## Rate limits and spend caps

Every `ai-proxy` call passes through `consume_ai_quota` before the provider is
contacted. The check and the counter increment happen in a single statement that
holds a row lock, so concurrent edge function isolates serialize on it rather
than each reading a stale count and letting a burst through.

Limits depend on who pays:

| Limit                       | Platform key (ShiftAI pays) | User's own key (user pays) |
|-----------------------------|-----------------------------|----------------------------|
| `requests_per_minute`       | enforced                    | enforced                   |
| `requests_per_day`          | enforced                    | generous abuse guard       |
| `tokens_per_day`            | enforced — the spend cap    | not capped                 |

Shipped plans (`public.ai_plans`):

| Plan        | req/min | platform req/day | platform tokens/day | BYOK req/day |
|-------------|---------|------------------|---------------------|--------------|
| `free`      | 20      | 100              | 100,000             | 2,000        |
| `pro`       | 60      | 5,000            | 5,000,000           | 20,000       |
| `unlimited` | none    | none             | none                | none         |

Users with no `user_ai_plan` row get `free`. **Review these numbers against your
provider pricing before opening signups** — they are conservative placeholders,
not a budget you have agreed to.

A refused request returns `429` with a `Retry-After` header and a JSON body
naming the limit hit; a blocked account returns `403`. Successful responses
carry `x-ratelimit-remaining-requests` and `x-ratelimit-remaining-tokens`.

Assign a plan, or block an account outright:

```sql
insert into public.user_ai_plan (user_id, plan_id) values ('<user-uuid>', 'pro')
on conflict (user_id) do update set plan_id = excluded.plan_id;

update public.user_ai_plan set is_blocked = true where user_id = '<user-uuid>';
```

Tune a plan globally:

```sql
update public.ai_plans set platform_tokens_per_day = 250000 where id = 'free';
```

The app can show remaining allowance by selecting from `public.my_ai_quota`.

### Schedule counter pruning

Minute buckets accumulate quickly. Enable `pg_cron` and prune daily:

```sql
create extension if not exists pg_cron with schema extensions;
select cron.schedule(
  'prune-ai-usage-counters', '17 4 * * *',
  $$ select public.prune_ai_usage_counters(interval '3 days') $$
);
```

### What this does *not* do yet

- **No per-request authorization beyond authentication.** Any signed-in user may
  use the platform key for any enabled provider, within their quota.
- **Streaming responses are not token-accounted.** Their token counts are not
  available without buffering the stream, so SSE requests count against the
  request limits but contribute nothing to the daily token cap. If most of your
  traffic streams, the token cap will under-count — lean on `requests_per_day`.
- **The token cap can overshoot by one response.** Tokens are charged after the
  provider answers, so the request that crosses the cap still completes.
- **Limits are per user, not global.** There is no account-wide ShiftAI spend
  ceiling; many users each within quota can still add up.

## Operations

Rotate a key:

```sql
select public.store_provider_key('openai', 'sk-new...', 'default', null);
```

Revoke one (drops the vault secret too):

```sql
select public.revoke_provider_key('<key-uuid>');
```

Relax a provider's key format check if a provider changes its prefix:

```sql
update public.ai_providers set key_pattern = null where id = 'openai';
```

Add a provider:

```sql
insert into public.ai_providers
  (id, display_name, base_url, auth_scheme, auth_name, verify_path, chat_path)
values
  ('mistral', 'Mistral', 'https://api.mistral.ai', 'bearer', 'Authorization',
   '/v1/models', '/v1/chat/completions');
```
