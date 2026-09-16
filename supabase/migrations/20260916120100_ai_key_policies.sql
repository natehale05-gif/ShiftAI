-- ShiftAI :: RLS, safe views, and the RPCs that mediate key access.

-- ---------------------------------------------------------------------------
-- Role helper
-- ---------------------------------------------------------------------------

create or replace function public.is_service_role()
returns boolean
language sql
stable
set search_path = public
as $$
  select current_user = 'service_role'
      or coalesce(current_setting('request.jwt.claims', true)::jsonb ->> 'role', '') = 'service_role';
$$;

revoke execute on function public.is_service_role() from public;
grant execute on function public.is_service_role() to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------

alter table public.ai_providers      enable row level security;
alter table public.ai_provider_keys  enable row level security;
alter table public.ai_usage_events   enable row level security;

-- Provider catalogue: readable by signed-in users, writable by service_role only.
drop policy if exists ai_providers_read on public.ai_providers;
create policy ai_providers_read
  on public.ai_providers for select
  to authenticated
  using (is_enabled);

-- Key metadata: a user may read the metadata of their own keys and nothing else.
-- Platform keys (owner_id is null) are invisible to every client role.
drop policy if exists ai_provider_keys_read_own on public.ai_provider_keys;
create policy ai_provider_keys_read_own
  on public.ai_provider_keys for select
  to authenticated
  using (owner_id = (select auth.uid()));

-- No INSERT/UPDATE/DELETE policies exist for client roles by design: all writes
-- must go through the SECURITY DEFINER RPCs below so the vault secret and the
-- metadata row are created and destroyed together.

drop policy if exists ai_usage_events_read_own on public.ai_usage_events;
create policy ai_usage_events_read_own
  on public.ai_usage_events for select
  to authenticated
  using (user_id = (select auth.uid()));

-- Table-level grants. Note the deliberate absence of ai_provider_keys: clients
-- read it through the view below, which cannot leak secret_id.
revoke all on public.ai_provider_keys from anon, authenticated;
revoke all on public.ai_providers     from anon, authenticated;
revoke all on public.ai_usage_events  from anon, authenticated;

grant select on public.ai_providers    to authenticated;
grant select on public.ai_usage_events to authenticated;

-- ---------------------------------------------------------------------------
-- Client-facing view (no secret_id column, RLS of the invoker applies)
-- ---------------------------------------------------------------------------

create or replace view public.my_ai_keys
with (security_invoker = true)
as
  select
    k.id,
    k.provider_id,
    p.display_name as provider_name,
    k.label,
    k.key_hint,
    k.is_active,
    k.last_used_at,
    k.last_verified_at,
    k.created_at,
    k.updated_at
  from public.ai_provider_keys k
  join public.ai_providers p on p.id = k.provider_id
  where k.owner_id = (select auth.uid());

revoke all on public.my_ai_keys from anon;
grant select on public.my_ai_keys to authenticated;

-- security_invoker views still need the underlying SELECT privilege, granted
-- narrowly here to the safe columns only.
grant select (id, owner_id, provider_id, label, key_hint, is_active,
              last_used_at, last_verified_at, created_at, updated_at)
  on public.ai_provider_keys to authenticated;

-- ---------------------------------------------------------------------------
-- store_provider_key: create or rotate a key
-- ---------------------------------------------------------------------------

create or replace function public.store_provider_key(
  p_provider text,
  p_secret   text,
  p_label    text default 'default',
  p_owner    uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public, vault, extensions
as $$
declare
  v_owner     uuid;
  v_provider  public.ai_providers%rowtype;
  v_existing  public.ai_provider_keys%rowtype;
  v_secret    text := btrim(coalesce(p_secret, ''));
  v_label     text := coalesce(nullif(btrim(p_label), ''), 'default');
  v_hint      text;
  v_secret_id uuid;
  v_key_id    uuid;
begin
  -- Caller identity: only service_role may write a key on behalf of someone
  -- else, or write a platform key (p_owner null).
  if public.is_service_role() then
    v_owner := p_owner;
  else
    v_owner := (select auth.uid());
    if v_owner is null then
      raise exception 'authentication required' using errcode = '42501';
    end if;
    if p_owner is not null and p_owner <> v_owner then
      raise exception 'cannot store a key for another user' using errcode = '42501';
    end if;
  end if;

  if char_length(v_secret) < 16 then
    raise exception 'api key looks too short to be valid' using errcode = '22023';
  end if;

  select * into v_provider
    from public.ai_providers
   where id = p_provider and is_enabled;
  if not found then
    raise exception 'unknown or disabled provider: %', p_provider using errcode = '22023';
  end if;

  if v_provider.key_pattern is not null and v_secret !~ v_provider.key_pattern then
    raise exception 'api key does not match the expected format for %', p_provider
      using errcode = '22023';
  end if;

  v_hint := right(v_secret, 4);

  select * into v_existing
    from public.ai_provider_keys
   where provider_id = p_provider
     and label = v_label
     and owner_id is not distinct from v_owner;

  if found then
    -- Rotation: replace the vault secret in place, keep the row identity so
    -- usage history stays attached.
    perform vault.update_secret(v_existing.secret_id, v_secret);
    update public.ai_provider_keys
       set key_hint = v_hint,
           is_active = true,
           last_verified_at = null
     where id = v_existing.id;
    return v_existing.id;
  end if;

  v_secret_id := vault.create_secret(
    v_secret,
    format('shiftai:%s:%s:%s',
           coalesce(v_owner::text, 'platform'),
           p_provider,
           regexp_replace(v_label, '[^A-Za-z0-9_.\-]', '_', 'g')),
    format('ShiftAI %s key', p_provider)
  );

  insert into public.ai_provider_keys (owner_id, provider_id, label, secret_id, key_hint)
  values (v_owner, p_provider, v_label, v_secret_id, v_hint)
  returning id into v_key_id;

  return v_key_id;
end;
$$;

revoke execute on function public.store_provider_key(text, text, text, uuid) from public, anon;
grant execute on function public.store_provider_key(text, text, text, uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- revoke_provider_key: destroy the vault secret and the metadata row
-- ---------------------------------------------------------------------------

create or replace function public.revoke_provider_key(p_key_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, vault, extensions
as $$
declare
  v_row public.ai_provider_keys%rowtype;
begin
  select * into v_row from public.ai_provider_keys where id = p_key_id;
  if not found then
    return false;
  end if;

  if not public.is_service_role() then
    if v_row.owner_id is null or v_row.owner_id <> (select auth.uid()) then
      raise exception 'not your key' using errcode = '42501';
    end if;
  end if;

  delete from public.ai_provider_keys where id = v_row.id;
  delete from vault.secrets where id = v_row.secret_id;
  return true;
end;
$$;

revoke execute on function public.revoke_provider_key(uuid) from public, anon;
grant execute on function public.revoke_provider_key(uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- get_active_provider_key: the ONLY path to plaintext. service_role only.
-- ---------------------------------------------------------------------------

create or replace function public.get_active_provider_key(
  p_provider text,
  p_owner    uuid default null,
  p_label    text default null
)
returns table (key_id uuid, api_key text, key_scope text)
language plpgsql
security definer
set search_path = public, vault, extensions
as $$
begin
  if not public.is_service_role() then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  return query
    select k.id,
           s.decrypted_secret,
           case when k.owner_id is null then 'platform' else 'user' end
      from public.ai_provider_keys k
      join vault.decrypted_secrets s on s.id = k.secret_id
     where k.provider_id = p_provider
       and k.is_active
       and (p_label is null or k.label = p_label)
       and (k.owner_id = p_owner or k.owner_id is null)
     -- a user's own key always wins over the platform fallback
     order by (k.owner_id is null), k.created_at desc
     limit 1;
end;
$$;

revoke execute on function public.get_active_provider_key(text, uuid, text) from public, anon, authenticated;
grant execute on function public.get_active_provider_key(text, uuid, text) to service_role;
