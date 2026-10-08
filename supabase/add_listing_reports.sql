create table if not exists public.listing_reports (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.scraped_listings(id) on delete cascade,
  reporter_id uuid not null references auth.users(id),
  reason text not null
    check (reason in ('fake', 'wrong_info', 'duplicate', 'rented_out', 'other')),
  description text check (description is null or char_length(description) <= 1000),
  status text not null default 'new'
    check (status in ('new', 'reviewed', 'dismissed')),
  created_at timestamptz not null default now()
);

alter table public.listing_reports enable row level security;

drop policy if exists "authenticated users create listing reports"
  on public.listing_reports;
create policy "authenticated users create listing reports"
  on public.listing_reports for insert
  to authenticated
  with check (reporter_id = auth.uid());

drop policy if exists "admins read listing reports"
  on public.listing_reports;
create policy "admins read listing reports"
  on public.listing_reports for select
  to authenticated
  using (public.is_admin());

drop policy if exists "admins update listing reports"
  on public.listing_reports;
create policy "admins update listing reports"
  on public.listing_reports for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create index if not exists listing_reports_listing_idx
  on public.listing_reports (listing_id, created_at desc);

notify pgrst, 'reload schema';
