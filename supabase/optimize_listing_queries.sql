-- Indexes used by the public recommended-listing query.
-- Safe to run more than once.

create index if not exists scraped_listings_parsed_data_gin_idx
  on public.scraped_listings using gin (parsed_data jsonb_path_ops);

create index if not exists scraped_listings_manual_ads_recent_idx
  on public.scraped_listings (created_at desc)
  where status = 'approved'
    and parsed_data @> '{"manual_entry": true}'::jsonb;

analyze public.scraped_listings;
