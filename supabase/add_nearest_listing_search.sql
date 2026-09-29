-- Return no more than nine approved listings in the selected area, ordered by
-- their distance from the searching user's current location.
create or replace function public.search_nearest_listings(
  center_lat double precision,
  center_lng double precision,
  filter_province text default null,
  filter_district text default null,
  filter_village text default null
)
returns table (
  id uuid,
  title text,
  monthly_price numeric,
  monthly_price_min numeric,
  monthly_price_max numeric,
  currency text,
  province text,
  district text,
  village text,
  source_url text,
  contact_phone text,
  property_type text,
  thumbnail_url text,
  gallery_urls text[],
  map_url text,
  latitude double precision,
  longitude double precision,
  parsed_data jsonb,
  distance_meters double precision
)
language sql
stable
set search_path = public
as $$
  with distances as (
    select
      sl.*,
      6371000.0 * acos(
        least(1.0, greatest(-1.0,
          sin(radians(center_lat)) * sin(radians(sl.latitude)) +
          cos(radians(center_lat)) * cos(radians(sl.latitude)) *
          cos(radians(sl.longitude) - radians(center_lng))
        ))
      ) as calculated_distance
    from public.scraped_listings sl
    where sl.status = 'approved'
      and sl.latitude is not null
      and sl.longitude is not null
      and sl.parsed_data @> '{"manual_entry": true}'::jsonb
      and (sl.source_posted_at is null or sl.source_posted_at >= now() - interval '1 year')
      and (filter_province is null or sl.province = filter_province)
      and (filter_district is null or sl.district = filter_district)
      and (filter_village is null or sl.village = filter_village)
  )
  select
    id, title, monthly_price, monthly_price_min, monthly_price_max, currency,
    province, district, village, source_url, contact_phone, property_type,
    thumbnail_url, gallery_urls, map_url, latitude, longitude, parsed_data,
    calculated_distance
  from distances
  order by calculated_distance
  limit 9;
$$;

grant execute on function public.search_nearest_listings(
  double precision, double precision, text, text, text
) to anon, authenticated;

notify pgrst, 'reload schema';
