create table if not exists public.listing_advertisements (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.scraped_listings(id) on delete cascade,
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null,
  active boolean not null default true,
  priority integer not null default 0,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create index if not exists listing_advertisements_schedule_idx
  on public.listing_advertisements(active, starts_at, ends_at, priority desc);

alter table public.listing_advertisements enable row level security;

drop policy if exists "public reads active listing ads"
  on public.listing_advertisements;
create policy "public reads active listing ads"
  on public.listing_advertisements for select
  using ((active and now() between starts_at and ends_at) or public.is_admin());

drop policy if exists "admins manage listing ads"
  on public.listing_advertisements;
create policy "admins manage listing ads"
  on public.listing_advertisements for all
  using (public.is_admin())
  with check (public.is_admin());
