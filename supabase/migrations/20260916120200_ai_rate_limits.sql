-- ShiftAI :: rate limits and spend caps for AI requests.
--
-- Enforcement lives in the database, not in the edge function: concurrent
-- function isolates would each read a stale count and let a burst through. Here
-- the counter row is locked for the duration of the check, so N concurrent
-- requests serialize on it and the (N+1)th is refused.
--
-- Limits differ by who pays. A request served by a ShiftAI platform key costs
-- ShiftAI money, so it gets request and token caps. A request served by the
-- user's own key costs the user, so it gets only a generous abuse guard.

-- ---------------------------------------------------------------------------
-- Plans
-- ---------------------------------------------------------------------------

create table if not exists public.ai_plans (
  id                       text primary key,
  display_name             text not null,
  -- NULL anywhere below means "no limit"
  requests_per_minute      int,     -- burst guard, applies to every request
  platform_requests_per_day int,    -- requests billed to ShiftAI
  platform_tokens_per_day  bigint,  -- the actual spend cap
  user_requests_per_day    int,     -- bring-your-own-key abuse guard
  created_at               timestamptz not null default now()
);

comment on table public.ai_plans is
  'Named limit sets. Users without a user_ai_plan row fall back to the "free" plan.';

insert into public.ai_plans
  (id, display_name, requests_per_minute, platform_requests_per_day, platform_tokens_per_day, user_requests_per_day)
values
  -- Deliberately conservative: an open signup flow can otherwise run up an
  -- unbounded provider bill on the platform key. Raise per account as needed.
  ('free',      'Free',      20,   100,   100000,  2000),
  ('pro',       'Pro',       60,   5000,  5000000, 20000),
  ('unlimited', 'Unlimited', null, null,  null,    null)
on conflict (id) do nothing;

create table if not exists public.user_ai_plan (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  plan_id    text not null references public.ai_plans (id) on update cascade,
  is_blocked boolean not null default false,
  note       text,
  updated_at timestamptz not null default now()
);

comment on column public.user_ai_plan.is_blocked is
  'Hard kill switch for one account; refuses every AI request regardless of plan.';

drop trigger if exists set_updated_at on public.user_ai_plan;
create trigger set_updated_at
  before update on public.user_ai_plan
  for each row execute function public.tg_set_updated_at();

-- ---------------------------------------------------------------------------
-- Counters
-- ---------------------------------------------------------------------------

create table if not exists public.ai_usage_counters (
  subject_id   uuid not null references auth.users (id) on delete cascade,
  key_scope    text not null check (key_scope in ('user', 'platform')),
  window_kind  text not null check (window_kind in ('minute', 'day')),
  window_start timestamptz not null,
  requests     int not null default 0,
  tokens       bigint not null default 0,
  primary key (subject_id, key_scope, window_kind, window_start)
);

create index if not exists ai_usage_counters_window_idx
  on public.ai_usage_counters (window_start);

-- ---------------------------------------------------------------------------
-- consume_ai_quota: the gate. service_role only.
-- ---------------------------------------------------------------------------

create or replace function public.consume_ai_quota(
  p_user      uuid,
  p_key_scope text
)
returns table (
  allowed                 boolean,
  reason                  text,
  limit_name              text,
  retry_after_seconds     int,
  requests_remaining_day  int,
  tokens_remaining_day    bigint
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_plan          public.ai_plans%rowtype;
  v_plan_id       text;
  v_blocked       boolean;
  v_minute        timestamptz := date_trunc('minute', now());
  v_day           timestamptz := date_trunc('day', now());
  v_min_requests  int;
  v_day_requests  int;
  v_day_tokens    bigint;
  v_rpm           int;
  v_req_day       int;
  v_tok_day       bigint;
begin
  if not public.is_service_role() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_user is null then
    raise exception 'p_user is required' using errcode = '22023';
  end if;
  if p_key_scope not in ('user', 'platform') then
    raise exception 'invalid key scope: %', p_key_scope using errcode = '22023';
  end if;

  select plan_id, is_blocked into v_plan_id, v_blocked
    from public.user_ai_plan where user_id = p_user;
  if not found then
    v_plan_id := 'free';
    v_blocked := false;
  end if;

  if v_blocked then
    return query select false, 'this account is blocked from making AI requests',
                        'account_blocked', null::int, 0, 0::bigint;
    return;
  end if;

  select * into v_plan from public.ai_plans where id = v_plan_id;
  if not found then
    select * into v_plan from public.ai_plans where id = 'free';
  end if;

  v_rpm := v_plan.requests_per_minute;
  if p_key_scope = 'platform' then
    v_req_day := v_plan.platform_requests_per_day;
    v_tok_day := v_plan.platform_tokens_per_day;
  else
    -- The user is paying their own provider bill; cap only to stop abuse.
    v_req_day := v_plan.user_requests_per_day;
    v_tok_day := null;
  end if;

  -- Take and hold the row lock for both windows. The no-op SET is what makes
  -- ON CONFLICT lock the existing row; without it a concurrent caller could
  -- read the same count and both would be admitted.
  insert into public.ai_usage_counters as c
    (subject_id, key_scope, window_kind, window_start)
  values (p_user, p_key_scope, 'minute', v_minute)
  on conflict (subject_id, key_scope, window_kind, window_start)
  do update set requests = c.requests
  returning c.requests into v_min_requests;

  insert into public.ai_usage_counters as c
    (subject_id, key_scope, window_kind, window_start)
  values (p_user, p_key_scope, 'day', v_day)
  on conflict (subject_id, key_scope, window_kind, window_start)
  do update set requests = c.requests
  returning c.requests, c.tokens into v_day_requests, v_day_tokens;

  if v_rpm is not null and v_min_requests >= v_rpm then
    return query select
      false,
      format('rate limit reached: %s requests per minute', v_rpm),
      'requests_per_minute',
      greatest(1, ceil(extract(epoch from (v_minute + interval '1 minute' - now())))::int),
      case when v_req_day is null then null else greatest(0, v_req_day - v_day_requests) end,
      case when v_tok_day is null then null else greatest(0, v_tok_day - v_day_tokens) end;
    return;
  end if;

  if v_req_day is not null and v_day_requests >= v_req_day then
    return query select
      false,
      format('daily limit reached: %s requests per day', v_req_day),
      'requests_per_day',
      greatest(1, ceil(extract(epoch from (v_day + interval '1 day' - now())))::int),
      0,
      case when v_tok_day is null then null else greatest(0, v_tok_day - v_day_tokens) end;
    return;
  end if;

  -- Tokens are charged after the fact, so the final request of a day may
  -- overshoot the cap by one response. Size the cap with that in mind.
  if v_tok_day is not null and v_day_tokens >= v_tok_day then
    return query select
      false,
      format('daily token cap reached: %s tokens per day', v_tok_day),
      'tokens_per_day',
      greatest(1, ceil(extract(epoch from (v_day + interval '1 day' - now())))::int),
      case when v_req_day is null then null else greatest(0, v_req_day - v_day_requests) end,
      0::bigint;
    return;
  end if;

  update public.ai_usage_counters
     set requests = requests + 1
   where subject_id = p_user and key_scope = p_key_scope
     and window_kind = 'minute' and window_start = v_minute;

  update public.ai_usage_counters
     set requests = requests + 1
   where subject_id = p_user and key_scope = p_key_scope
     and window_kind = 'day' and window_start = v_day;

  return query select
    true,
    null::text,
    null::text,
    null::int,
    case when v_req_day is null then null else greatest(0, v_req_day - v_day_requests - 1) end,
    case when v_tok_day is null then null else greatest(0, v_tok_day - v_day_tokens) end;
end;
$$;

revoke execute on function public.consume_ai_quota(uuid, text) from public, anon, authenticated;
grant execute on function public.consume_ai_quota(uuid, text) to service_role;

-- ---------------------------------------------------------------------------
-- record_ai_tokens: charge actual usage once the provider has answered.
-- ---------------------------------------------------------------------------

create or replace function public.record_ai_tokens(
  p_user      uuid,
  p_key_scope text,
  p_tokens    bigint
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not public.is_service_role() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_user is null or coalesce(p_tokens, 0) <= 0 then
    return;
  end if;

  insert into public.ai_usage_counters as c
    (subject_id, key_scope, window_kind, window_start, requests, tokens)
  values (p_user, p_key_scope, 'day', date_trunc('day', now()), 0, p_tokens)
  on conflict (subject_id, key_scope, window_kind, window_start)
  do update set tokens = c.tokens + excluded.tokens;
end;
$$;

revoke execute on function public.record_ai_tokens(uuid, text, bigint) from public, anon, authenticated;
grant execute on function public.record_ai_tokens(uuid, text, bigint) to service_role;

-- ---------------------------------------------------------------------------
-- prune_ai_usage_counters: minute buckets accumulate fast. Schedule this.
-- ---------------------------------------------------------------------------

create or replace function public.prune_ai_usage_counters(p_keep interval default interval '3 days')
returns bigint
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_deleted bigint;
begin
  if not public.is_service_role() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  delete from public.ai_usage_counters where window_start < now() - p_keep;
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

revoke execute on function public.prune_ai_usage_counters(interval) from public, anon, authenticated;
grant execute on function public.prune_ai_usage_counters(interval) to service_role;
