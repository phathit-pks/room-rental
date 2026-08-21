create table if not exists public.scraped_listings (
  id uuid primary key default gen_random_uuid(),
  raw_text text not null,
  source_url text,
  source_posted_at timestamptz,
  parsed_data jsonb not null default '{}'::jsonb,
  title text,
  property_type text check (property_type in ('room', 'apartment', 'house', 'condo')),
  thumbnail_url text,
  gallery_urls text[] not null default '{}',
  map_url text,
  latitude double precision,
  longitude double precision,
  monthly_price numeric(14,2),
  monthly_price_min numeric(14,2),
  monthly_price_max numeric(14,2),
  currency text check (currency in ('LAK', 'THB', 'USD')),
  province text,
  district text,
  village text,
  contact_phone text,
  status text not null default 'pending_review'
    check (status in ('pending_review', 'approved', 'rejected', 'outdated')),
  created_by uuid not null default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    monthly_price_min is null
    or monthly_price_max is null
    or monthly_price_max >= monthly_price_min
  )
);

create unique index if not exists scraped_listings_source_url_unique
  on public.scraped_listings (source_url)
  where source_url is not null and source_url <> '';

create index if not exists scraped_listings_status_created_idx
  on public.scraped_listings (status, created_at desc);

alter table public.scraped_listings enable row level security;

drop policy if exists "admins read scraped listings" on public.scraped_listings;
create policy "admins read scraped listings"
  on public.scraped_listings for select
  using (public.is_admin());

drop policy if exists "public reads approved scraped listings" on public.scraped_listings;
create policy "public reads approved scraped listings"
  on public.scraped_listings for select
  using (status = 'approved');

drop policy if exists "admins insert scraped listings" on public.scraped_listings;
create policy "admins insert scraped listings"
  on public.scraped_listings for insert
  with check (public.is_admin() and created_by = auth.uid());

drop policy if exists "admins update scraped listings" on public.scraped_listings;
create policy "admins update scraped listings"
  on public.scraped_listings for update
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "admins delete scraped listings" on public.scraped_listings;
create policy "admins delete scraped listings"
  on public.scraped_listings for delete
  using (public.is_admin());
