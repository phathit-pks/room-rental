alter table public.scraped_listings
  add column if not exists property_type text;

update public.scraped_listings
set property_type = coalesce(
  nullif(parsed_data ->> 'property_type', ''),
  'apartment'
)
where property_type is null;

alter table public.scraped_listings
  drop constraint if exists scraped_listings_property_type_check;
alter table public.scraped_listings
  add constraint scraped_listings_property_type_check
  check (property_type in ('room', 'apartment', 'house', 'condo'));

create index if not exists scraped_listings_property_type_idx
  on public.scraped_listings (property_type, status);
