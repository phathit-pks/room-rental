-- Each signed-in client may submit one room listing. Admin-created listings are
-- excluded because they do not carry parsed_data.client_submission = true.

create unique index if not exists scraped_listings_one_client_submission_idx
  on public.scraped_listings (created_by)
  where coalesce((parsed_data->>'client_submission')::boolean, false);

notify pgrst, 'reload schema';
