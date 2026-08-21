create index if not exists scraped_listings_coordinates_idx
  on public.scraped_listings (latitude, longitude)
  where latitude is not null and longitude is not null;

drop function if exists public.search_listings_in_radius(
  double precision,
  double precision,
  double precision
);

create function public.search_listings_in_radius(
  center_lat double precision,
  center_lng double precision,
  radius_meters double precision
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
      and sl.latitude between center_lat - (radius_meters / 111320.0)
                          and center_lat + (radius_meters / 111320.0)
      and sl.longitude between center_lng - (radius_meters / (111320.0 * greatest(0.1, cos(radians(center_lat)))))
                           and center_lng + (radius_meters / (111320.0 * greatest(0.1, cos(radians(center_lat)))))
  )
  select
    distances.id,
    distances.title,
    distances.monthly_price,
    distances.monthly_price_min,
    distances.monthly_price_max,
    distances.currency,
    distances.province,
    distances.district,
    distances.village,
    distances.source_url,
    distances.contact_phone,
    distances.property_type,
    distances.thumbnail_url,
    distances.gallery_urls,
    distances.map_url,
    distances.latitude,
    distances.longitude,
    distances.parsed_data,
    distances.calculated_distance
  from distances
  where distances.calculated_distance <= radius_meters
  order by distances.calculated_distance
  limit 30;
$$;

grant execute on function public.search_listings_in_radius(
  double precision,
  double precision,
  double precision
) to anon, authenticated;

notify pgrst, 'reload schema';
