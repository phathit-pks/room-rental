alter table public.scraped_listings
  add column if not exists monthly_price_min numeric(14,2),
  add column if not exists monthly_price_max numeric(14,2);

update public.scraped_listings
set monthly_price_min = coalesce(monthly_price_min, monthly_price),
    monthly_price_max = coalesce(monthly_price_max, monthly_price)
where monthly_price is not null;

alter table public.scraped_listings
  drop constraint if exists scraped_listings_price_range_check;
alter table public.scraped_listings
  add constraint scraped_listings_price_range_check
  check (
    monthly_price_min is null
    or monthly_price_max is null
    or monthly_price_max >= monthly_price_min
  );
