alter table public.scraped_listings
  add column if not exists thumbnail_url text;
