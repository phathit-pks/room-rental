alter table public.scraped_listings
  add column if not exists map_url text,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;

alter table public.scraped_listings
  drop constraint if exists scraped_listings_coordinates_check;
alter table public.scraped_listings
  add constraint scraped_listings_coordinates_check check (
    (latitude is null and longitude is null)
    or (latitude between -90 and 90 and longitude between -180 and 180)
  );

notify pgrst, 'reload schema';
