-- Permanently delete only listings whose source belongs to rentlaos.com.
-- Run once in Supabase SQL Editor. Deleted rows require a backup to recover.

delete from public.scraped_listings
where coalesce(source_url, '') ~* '^https?://([^/]+\.)?rentlaos\.com(/|$)'
   or coalesce(parsed_data ->> 'source_url', '')
      ~* '^https?://([^/]+\.)?rentlaos\.com(/|$)'
returning id, title, source_url;
