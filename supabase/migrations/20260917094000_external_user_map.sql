-- ShiftAI :: map ShiftAI's own user ids onto mirrored Supabase Auth users.
--
-- ShiftAI's users live in its application database behind its own JWT secret.
-- Mirroring them into auth.users keeps the key and quota schema working as
-- designed (owner_id and subject_id stay real foreign keys, RLS keeps working
-- off auth.uid()), and this table is the correspondence between the two ids.
--
-- Supabase assigns its own uuid on create, so the mapping is stored rather than
-- assumed: nothing here requires the two systems to agree on an id.

create table if not exists public.external_user_map (
  external_id text primary key,
  user_id     uuid not null unique references auth.users (id) on delete cascade,
  source      text not null default 'shiftai',
  email       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.external_user_map is
  'external_id is the user id in ShiftAI''s own database; user_id is the mirrored Supabase Auth user.';

create index if not exists external_user_map_user_idx on public.external_user_map (user_id);

drop trigger if exists set_updated_at on public.external_user_map;
create trigger set_updated_at
  before update on public.external_user_map
  for each row execute function public.tg_set_updated_at();

-- Service-role only: RLS is on with no policies at all, so no client role can
-- read the mapping even though the table lives in the public schema.
alter table public.external_user_map enable row level security;
revoke all on public.external_user_map from anon, authenticated;

-- ---------------------------------------------------------------------------
-- find_auth_user_by_email: lets the sync script recover from a half-finished
-- run (user created in Auth, mapping row never written) without listing every
-- user in the project.
-- ---------------------------------------------------------------------------

create or replace function public.find_auth_user_by_email(p_email text)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_id uuid;
begin
  if not public.is_service_role() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  select id into v_id from auth.users
   where lower(email) = lower(btrim(p_email))
   limit 1;
  return v_id;
end;
$$;

revoke execute on function public.find_auth_user_by_email(text) from public, anon, authenticated;
grant execute on function public.find_auth_user_by_email(text) to service_role;

-- ---------------------------------------------------------------------------
-- resolve_external_user: the id translation the app needs at request time.
-- ---------------------------------------------------------------------------

create or replace function public.resolve_external_user(p_external_id text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if not public.is_service_role() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  select user_id into v_id from public.external_user_map where external_id = p_external_id;
  return v_id;
end;
$$;

revoke execute on function public.resolve_external_user(text) from public, anon, authenticated;
grant execute on function public.resolve_external_user(text) to service_role;
