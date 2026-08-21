alter table public.scraped_listings
  add column if not exists gallery_urls text[] not null default '{}';

notify pgrst, 'reload schema';
