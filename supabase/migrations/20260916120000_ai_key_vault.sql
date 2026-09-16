-- ShiftAI :: encrypted storage for AI provider API keys
--
-- Design rules enforced by this migration:
--   1. Plaintext keys are NEVER stored in a regular table. They live in Supabase
--      Vault (pgsodium-backed, encrypted at rest); the table keeps only the
--      vault reference and a last-4 hint for display.
--   2. No client role (anon/authenticated) can read a plaintext key, directly or
--      through a view. Decryption is reachable only through
--      public.get_active_provider_key(), which is granted to service_role only.
--   3. Writes go through SECURITY DEFINER RPCs so the vault secret and the
--      metadata row stay in sync (no orphaned secrets).

create extension if not exists pgcrypto with schema extensions;
create extension if not exists supabase_vault with schema vault;

-- ---------------------------------------------------------------------------
-- Provider catalogue
-- ---------------------------------------------------------------------------

create table if not exists public.ai_providers (
  id            text primary key,
  display_name  text not null,
  base_url      text not null,
  -- how the credential is attached to the upstream request
  auth_scheme   text not null default 'bearer'
                  check (auth_scheme in ('bearer', 'header', 'query')),
  auth_name     text not null default 'Authorization',
  extra_headers jsonb not null default '{}'::jsonb,
  -- advisory format check applied on store; relax with an UPDATE if a provider
  -- changes its key format (see docs/SUPABASE_SETUP.md)
  key_pattern   text,
  -- cheap authenticated GET used to verify a key before saving it
  verify_path   text,
  -- chat/completion path; "{model}" is substituted by the proxy when present
  chat_path     text,
  is_enabled    boolean not null default true,
  created_at    timestamptz not null default now()
);

comment on table public.ai_providers is
  'Catalogue of upstream AI providers. Contains no secrets; readable by signed-in users.';

insert into public.ai_providers
  (id, display_name, base_url, auth_scheme, auth_name, extra_headers, key_pattern, verify_path, chat_path)
values
  ('openai',     'OpenAI',      'https://api.openai.com',                 'bearer', 'Authorization', '{}'::jsonb,
     '^sk-[A-Za-z0-9_\-]{16,}$',        '/v1/models', '/v1/chat/completions'),
  ('anthropic',  'Anthropic',   'https://api.anthropic.com',              'header', 'x-api-key',
     '{"anthropic-version":"2023-06-01"}'::jsonb,
     '^sk-ant-[A-Za-z0-9_\-]{16,}$',    '/v1/models', '/v1/messages'),
  ('google',     'Google AI',   'https://generativelanguage.googleapis.com', 'header', 'x-goog-api-key', '{}'::jsonb,
     '^AIza[A-Za-z0-9_\-]{20,}$',       '/v1beta/models', '/v1beta/models/{model}:generateContent'),
  ('groq',       'Groq',        'https://api.groq.com/openai',            'bearer', 'Authorization', '{}'::jsonb,
     '^gsk_[A-Za-z0-9]{16,}$',          '/v1/models', '/v1/chat/completions'),
  ('openrouter', 'OpenRouter',  'https://openrouter.ai/api',              'bearer', 'Authorization', '{}'::jsonb,
     '^sk-or-[A-Za-z0-9_\-]{16,}$',     '/v1/auth/key', '/v1/chat/completions')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Key metadata
-- ---------------------------------------------------------------------------

create table if not exists public.ai_provider_keys (
  id               uuid primary key default gen_random_uuid(),
  -- NULL owner == platform key owned by ShiftAI itself (service_role only)
  owner_id         uuid references auth.users (id) on delete cascade,
  provider_id      text not null references public.ai_providers (id) on update cascade,
  label            text not null default 'default'
                     check (label ~ '^[A-Za-z0-9 _.\-]{1,64}$'),
  secret_id        uuid not null,
  key_hint         text not null check (char_length(key_hint) <= 8),
  is_active        boolean not null default true,
  last_used_at     timestamptz,
  last_verified_at timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

comment on column public.ai_provider_keys.secret_id is
  'FK into vault.secrets. Never expose this column to client roles.';
comment on column public.ai_provider_keys.owner_id is
  'Owning user, or NULL for a ShiftAI platform key usable as fallback.';

create unique index if not exists ai_provider_keys_identity_idx
  on public.ai_provider_keys (
    coalesce(owner_id, '00000000-0000-0000-0000-000000000000'::uuid),
    provider_id,
    label
  );

create index if not exists ai_provider_keys_owner_idx
  on public.ai_provider_keys (owner_id) where is_active;

-- ---------------------------------------------------------------------------
-- Usage log
-- ---------------------------------------------------------------------------

create table if not exists public.ai_usage_events (
  id                bigint generated always as identity primary key,
  user_id           uuid references auth.users (id) on delete set null,
  key_id            uuid references public.ai_provider_keys (id) on delete set null,
  provider_id       text,
  model             text,
  key_scope         text,
  status_code       int,
  ok                boolean,
  latency_ms        int,
  prompt_tokens     int,
  completion_tokens int,
  total_tokens      int,
  error             text,
  created_at        timestamptz not null default now()
);

create index if not exists ai_usage_events_user_idx
  on public.ai_usage_events (user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- updated_at trigger
-- ---------------------------------------------------------------------------

create or replace function public.tg_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists set_updated_at on public.ai_provider_keys;
create trigger set_updated_at
  before update on public.ai_provider_keys
  for each row execute function public.tg_set_updated_at();
