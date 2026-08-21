-- Run this file once in Supabase SQL Editor.
-- It is safe to run again because every column/index uses IF NOT EXISTS.

alter table public.scraped_listings
  add column if not exists monthly_price_min numeric(14,2),
  add column if not exists monthly_price_max numeric(14,2),
  add column if not exists property_type text,
  add column if not exists thumbnail_url text,
  add column if not exists gallery_urls text[] not null default '{}',
  add column if not exists map_url text,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;

update public.scraped_listings
set monthly_price_min = coalesce(monthly_price_min, monthly_price),
    monthly_price_max = coalesce(monthly_price_max, monthly_price),
    property_type = coalesce(
      property_type,
      nullif(parsed_data ->> 'property_type', ''),
      'apartment'
    );

-- Normalize old AI values to one of the four categories used by the website.
update public.scraped_listings
set property_type = 'apartment'
where property_type not in ('room', 'apartment', 'house', 'condo');

alter table public.scraped_listings
  drop constraint if exists scraped_listings_price_range_check;
alter table public.scraped_listings
  add constraint scraped_listings_price_range_check
  check (
    monthly_price_min is null
    or monthly_price_max is null
    or monthly_price_max >= monthly_price_min
  );

alter table public.scraped_listings
  drop constraint if exists scraped_listings_property_type_check;
alter table public.scraped_listings
  add constraint scraped_listings_property_type_check
  check (property_type in ('room', 'apartment', 'house', 'condo'));

create index if not exists scraped_listings_property_type_idx
  on public.scraped_listings (property_type, status);

-- Ask PostgREST to refresh its schema immediately.
notify pgrst, 'reload schema';
