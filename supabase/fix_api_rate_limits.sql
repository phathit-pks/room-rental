begin;

-- Per-user rate limits for outbound Edge Function requests.
create table if not exists public.api_rate_limits (
  user_id uuid not null references auth.users(id) on delete cascade,
  action text not null,
  window_started_at timestamptz not null,
  request_count integer not null check (request_count >= 0),
  primary key (user_id, action)
);

alter table public.api_rate_limits enable row level security;
grant select, insert, update, delete on public.api_rate_limits to service_role;
revoke all on table public.api_rate_limits from anon, authenticated;

create or replace function public.consume_api_rate_limit(requested_action text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  maximum_requests integer;
  request_time timestamptz := statement_timestamp();
  window_cutoff timestamptz := request_time - interval '1 hour';
begin
  if caller_id is null then
    return false;
  end if;

  case requested_action
    when 'resolve-google-maps-link' then maximum_requests := 20;
    when 'search-osm-places' then maximum_requests := 30;
    else return false;
  end case;

  insert into public.api_rate_limits as limits
    (user_id, action, window_started_at, request_count)
  values (caller_id, requested_action, request_time, 1)
  on conflict (user_id, action) do update
    set window_started_at = case
          when limits.window_started_at <= window_cutoff then request_time
          else limits.window_started_at
        end,
        request_count = case
          when limits.window_started_at <= window_cutoff then 1
          else limits.request_count + 1
        end
    where limits.window_started_at <= window_cutoff
       or limits.request_count < maximum_requests;

  return found;
end;
$$;

-- Keep deployed Edge Functions compatible during rollout. The legacy numeric
-- arguments are accepted but the database policy determines the quota.
create or replace function public.consume_api_rate_limit(
  requested_action text,
  maximum_requests integer,
  window_seconds integer
)
returns boolean
language sql
set search_path = ''
as $$
  select public.consume_api_rate_limit(requested_action);
$$;

revoke all on function public.consume_api_rate_limit(text)
  from public, anon;
revoke all on function public.consume_api_rate_limit(text, integer, integer)
  from public, anon;
grant execute on function public.consume_api_rate_limit(text)
  to authenticated;
grant execute on function public.consume_api_rate_limit(text, integer, integer)
  to authenticated;

notify pgrst, 'reload schema';

commit;
