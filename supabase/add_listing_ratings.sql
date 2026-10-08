create table if not exists public.listing_ratings (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.scraped_listings(id) on delete cascade,
  rater_id uuid not null references auth.users(id),
  rating smallint not null check (rating between 1 and 5),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (listing_id, rater_id)
);

alter table public.listing_ratings enable row level security;

drop policy if exists "anyone reads listing ratings"
  on public.listing_ratings;
create policy "anyone reads listing ratings"
  on public.listing_ratings for select
  to anon, authenticated
  using (true);

drop policy if exists "users rate listings"
  on public.listing_ratings;
create policy "users rate listings"
  on public.listing_ratings for insert
  to authenticated
  with check (rater_id = auth.uid());

drop policy if exists "users update own rating"
  on public.listing_ratings;
create policy "users update own rating"
  on public.listing_ratings for update
  to authenticated
  using (rater_id = auth.uid())
  with check (rater_id = auth.uid());

create index if not exists listing_ratings_listing_idx
  on public.listing_ratings (listing_id);

notify pgrst, 'reload schema';
