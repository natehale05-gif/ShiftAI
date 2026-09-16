# ShiftAI

ShiftAi App, Website, and Server

## Supabase key server

The `supabase/` directory holds the backend that stores AI provider API keys so
that no key is ever shipped inside the app. Keys are encrypted in Supabase
Vault, are unreadable by any client role, and are attached to upstream requests
inside an edge function.

```
supabase/
  migrations/     schema, row level security, key access RPCs
  functions/
    keys/         store, list, and revoke provider keys
    ai-proxy/     call a provider with the key injected server-side
docs/SUPABASE_SETUP.md   provisioning and operations
examples/client-usage.ts how the app calls it
scripts/smoke-test.sh    end-to-end check against a deployed project
```

Supports per-user bring-your-own-key credentials and ShiftAI-owned platform
keys with the same schema; a user's own key is preferred, the platform key is
the fallback.

**Setup:** see [docs/SUPABASE_SETUP.md](docs/SUPABASE_SETUP.md).

```bash
supabase link --project-ref <your-project-ref>
supabase db push
supabase functions deploy keys
supabase functions deploy ai-proxy
```

The service role key decrypts every stored credential. It belongs only in edge
function environments and trusted admin shells — never in an app bundle.
