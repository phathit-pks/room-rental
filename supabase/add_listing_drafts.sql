-- Allow admins to save incomplete listings as drafts before publishing.
-- Drafts stay private: public policies and search functions only return
-- status = 'approved'.

-- Drop the existing status check whatever it was named.
do $$
declare
  constraint_name text;
begin
  for constraint_name in
    select con.conname
    from pg_constraint con
    where con.conrelid = 'public.scraped_listings'::regclass
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) ilike '%status%'
  loop
    execute format(
      'alter table public.scraped_listings drop constraint %I',
      constraint_name
    );
  end loop;
end $$;

alter table public.scraped_listings
  add constraint scraped_listings_status_check
  check (status in ('draft', 'pending_review', 'approved', 'rejected', 'outdated'));

notify pgrst, 'reload schema';
