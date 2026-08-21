-- Client submissions are first-party posts. When an older row has no explicit
-- source timestamp, its creation time is the most accurate available value.
update public.scraped_listings
set source_posted_at = created_at,
    parsed_data = jsonb_set(
      coalesce(parsed_data, '{}'::jsonb),
      '{posted_at}',
      to_jsonb(created_at),
      true
    ),
    updated_at = now()
where source_posted_at is null
  and coalesce((parsed_data->>'client_submission')::boolean, false);

select id, title, source_posted_at
from public.scraped_listings
where coalesce((parsed_data->>'client_submission')::boolean, false)
order by created_at desc;
