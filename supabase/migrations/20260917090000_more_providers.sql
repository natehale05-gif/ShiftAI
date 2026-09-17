-- ShiftAI :: generalise the auth scheme and add the media providers the Suite
-- actually calls (ElevenLabs, HeyGen, Replicate, fal.ai, Flux, Runway, Luma).
--
-- The original 'bearer' | 'header' | 'query' enum could not express the schemes
-- these use: Replicate wants "Authorization: Token <key>" and fal.ai wants
-- "Authorization: Key <key>". Replacing the enum with an explicit prefix covers
-- all of them without another special case each time.

alter table public.ai_providers
  add column if not exists auth_prefix text not null default '';

comment on column public.ai_providers.auth_prefix is
  'Literal text prepended to the key in the auth header, e.g. "Bearer ", "Token ", "Key ". Empty for raw-value headers.';

update public.ai_providers set auth_prefix = 'Bearer ' where auth_scheme = 'bearer';

alter table public.ai_providers drop constraint if exists ai_providers_auth_scheme_check;
update public.ai_providers set auth_scheme = 'header' where auth_scheme = 'bearer';
alter table public.ai_providers
  add constraint ai_providers_auth_scheme_check check (auth_scheme in ('header', 'query'));

-- Media providers. chat_path is null where the provider is not chat-shaped: the
-- caller passes an explicit "path" to ai-proxy for those.
--
-- verify_path is set only where the endpoint is confirmed; a null simply skips
-- pre-storage verification rather than risking a false rejection of a good key.
insert into public.ai_providers
  (id, display_name, base_url, auth_scheme, auth_name, auth_prefix, extra_headers,
   key_pattern, verify_path, chat_path)
values
  ('elevenlabs', 'ElevenLabs', 'https://api.elevenlabs.io', 'header', 'xi-api-key', '',
     '{}'::jsonb, '^sk_[A-Za-z0-9]{24,}$', '/v1/user', null),
  ('heygen',     'HeyGen',     'https://api.heygen.com',    'header', 'X-Api-Key',  '',
     '{}'::jsonb, null, '/v1/user/remaining_quota', null),
  ('replicate',  'Replicate',  'https://api.replicate.com', 'header', 'Authorization', 'Token ',
     '{}'::jsonb, '^r8_[A-Za-z0-9]{20,}$', '/v1/account', null),
  ('fal',        'fal.ai',     'https://fal.run',           'header', 'Authorization', 'Key ',
     '{}'::jsonb, null, null, null),
  ('flux',       'Flux (BFL)', 'https://api.bfl.ai',        'header', 'x-key',      '',
     '{}'::jsonb, null, null, null),
  ('runway',     'Runway',     'https://api.dev.runwayml.com', 'header', 'Authorization', 'Bearer ',
     '{"X-Runway-Version":"2024-11-06"}'::jsonb, null, null, null),
  ('luma',       'Luma',       'https://api.lumalabs.ai',   'header', 'Authorization', 'Bearer ',
     '{}'::jsonb, null, null, null)
on conflict (id) do nothing;

-- Suno has no official public API; add a row here if you wire an unofficial one.
