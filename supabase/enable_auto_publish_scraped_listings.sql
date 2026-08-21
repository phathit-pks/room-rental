alter table public.scraped_listings
  alter column status set default 'approved';

drop policy if exists "public reads approved scraped listings"
  on public.scraped_listings;
create policy "public reads approved scraped listings"
  on public.scraped_listings for select
  using (status = 'approved');

update public.scraped_listings
set status = 'approved', updated_at = now()
where status = 'pending_review';
