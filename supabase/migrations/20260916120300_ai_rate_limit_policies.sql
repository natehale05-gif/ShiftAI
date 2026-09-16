-- ShiftAI :: RLS for the quota tables, plus the view the app reads to show
-- a user how much of their allowance is left.

alter table public.ai_plans          enable row level security;
alter table public.user_ai_plan      enable row level security;
alter table public.ai_usage_counters enable row level security;

drop policy if exists ai_plans_read on public.ai_plans;
create policy ai_plans_read
  on public.ai_plans for select
  to authenticated
  using (true);

-- A user may see which plan they are on, but not change it.
drop policy if exists user_ai_plan_read_own on public.user_ai_plan;
create policy user_ai_plan_read_own
  on public.user_ai_plan for select
  to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists ai_usage_counters_read_own on public.ai_usage_counters;
create policy ai_usage_counters_read_own
  on public.ai_usage_counters for select
  to authenticated
  using (subject_id = (select auth.uid()));

revoke all on public.ai_plans          from anon, authenticated;
revoke all on public.user_ai_plan      from anon, authenticated;
revoke all on public.ai_usage_counters from anon, authenticated;

grant select on public.ai_plans          to authenticated;
grant select on public.user_ai_plan      to authenticated;
grant select on public.ai_usage_counters to authenticated;

-- ---------------------------------------------------------------------------
-- my_ai_quota: today's usage against today's caps, for the caller only.
-- ---------------------------------------------------------------------------

create or replace view public.my_ai_quota
with (security_invoker = true)
as
  with me as (
    select
      (select auth.uid()) as user_id,
      coalesce(
        (select plan_id from public.user_ai_plan where user_id = (select auth.uid())),
        'free'
      ) as plan_id,
      coalesce(
        (select is_blocked from public.user_ai_plan where user_id = (select auth.uid())),
        false
      ) as is_blocked
  )
  select
    me.plan_id,
    p.display_name as plan_name,
    me.is_blocked,
    scopes.key_scope,
    coalesce(c.requests, 0) as requests_today,
    coalesce(c.tokens, 0)   as tokens_today,
    case when scopes.key_scope = 'platform'
         then p.platform_requests_per_day
         else p.user_requests_per_day end as requests_per_day,
    case when scopes.key_scope = 'platform'
         then p.platform_tokens_per_day
         else null::bigint end as tokens_per_day,
    p.requests_per_minute
  from me
  join public.ai_plans p on p.id = me.plan_id
  cross join (values ('user'), ('platform')) as scopes(key_scope)
  left join public.ai_usage_counters c
    on c.subject_id = me.user_id
   and c.key_scope = scopes.key_scope
   and c.window_kind = 'day'
   and c.window_start = date_trunc('day', now());

revoke all on public.my_ai_quota from anon;
grant select on public.my_ai_quota to authenticated;
