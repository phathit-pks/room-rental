-- Security hardening for profiles, public uploads, contact spam, and Edge Functions.
-- Apply this migration after the existing schema migrations.

-- Clients may update ordinary profile fields, but never their authorization role.
revoke update on table public.profiles from authenticated;
grant update (display_name, phone) on table public.profiles to authenticated;

create or replace function public.protect_profile_role()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.role is distinct from old.role and not public.is_admin() then
    raise exception 'Only an administrator may change profile roles';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_profile_role_update on public.profiles;
create trigger protect_profile_role_update
  before update on public.profiles
  for each row execute function public.protect_profile_role();

-- Keep the public image bucket usable, while limiting it to safe image formats
-- and the same 1 MB maximum enforced by the application.
update storage.buckets
set file_size_limit = 1048576,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
where id = 'property-images';

drop policy if exists "authenticated uploads property storage" on storage.objects;
create policy "users upload own property images"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'property-images'
    and (storage.foldername(name))[1] in ('thumbnails', 'gallery')
    and (storage.foldername(name))[2] = auth.uid()::text
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'webp')
  );

drop policy if exists "owners update property storage" on storage.objects;
create policy "users update own property images"
  on storage.objects for update to authenticated
  using (bucket_id = 'property-images' and owner_id = auth.uid()::text)
  with check (
    bucket_id = 'property-images'
    and owner_id = auth.uid()::text
    and (storage.foldername(name))[1] in ('thumbnails', 'gallery')
    and (storage.foldername(name))[2] = auth.uid()::text
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'webp')
  );

-- Anonymous contact insertion is disabled. Signed-in users get a small hourly
-- allowance enforced in the database, so bypassing the UI does not bypass it.
alter table public.contact_requests
  add column if not exists created_by uuid references auth.users(id) on delete set null
  default auth.uid();

drop policy if exists "public creates contact requests" on public.contact_requests;
create policy "authenticated creates contact requests"
  on public.contact_requests for insert to authenticated
  with check (created_by = auth.uid());

create or replace function public.limit_contact_requests()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or new.created_by is distinct from auth.uid() then
    raise exception 'Authentication required';
  end if;
  if (
    select count(*)
    from public.contact_requests
    where created_by = auth.uid()
      and created_at >= now() - interval '1 hour'
  ) >= 5 then
    raise exception 'Contact request rate limit exceeded';
  end if;
  return new;
end;
$$;

drop trigger if exists limit_contact_request_inserts on public.contact_requests;
create trigger limit_contact_request_inserts
  before insert on public.contact_requests
  for each row execute function public.limit_contact_requests();

-- Per-user rate limits for outbound Edge Function requests.
create table if not exists public.api_rate_limits (
  user_id uuid not null references auth.users(id) on delete cascade,
  action text not null,
  window_started_at timestamptz not null,
  request_count integer not null check (request_count >= 0),
  primary key (user_id, action)
);

alter table public.api_rate_limits enable row level security;
revoke all on table public.api_rate_limits from anon, authenticated;

create or replace function public.consume_api_rate_limit(
  requested_action text,
  maximum_requests integer,
  window_seconds integer
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_id uuid := auth.uid();
  current_row public.api_rate_limits%rowtype;
begin
  if caller_id is null then
    return false;
  end if;
  if requested_action not in ('resolve-google-maps-link', 'search-osm-places') then
    raise exception 'Unsupported rate-limit action';
  end if;
  maximum_requests := greatest(1, least(maximum_requests, 60));
  window_seconds := greatest(60, least(window_seconds, 86400));

  insert into public.api_rate_limits (user_id, action, window_started_at, request_count)
  values (caller_id, requested_action, now(), 1)
  on conflict (user_id, action) do update
    set window_started_at = case
          when public.api_rate_limits.window_started_at
            <= now() - make_interval(secs => window_seconds)
          then now()
          else public.api_rate_limits.window_started_at
        end,
        request_count = case
          when public.api_rate_limits.window_started_at
            <= now() - make_interval(secs => window_seconds)
          then 1
          else public.api_rate_limits.request_count + 1
        end
  returning * into current_row;

  return current_row.request_count <= maximum_requests;
end;
$$;

revoke all on function public.consume_api_rate_limit(text, integer, integer) from public;
grant execute on function public.consume_api_rate_limit(text, integer, integer)
  to authenticated;

notify pgrst, 'reload schema';
