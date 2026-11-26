begin;

-- Keep concurrent writes from introducing legacy data during the backfill.
lock table public.scraped_listings in share row exclusive mode;

create table if not exists public.scraped_listing_submitters (
  listing_id uuid primary key references public.scraped_listings(id) on delete cascade,
  email text not null
);

alter table public.scraped_listing_submitters enable row level security;
revoke all on public.scraped_listing_submitters from public, anon, authenticated;
grant select on public.scraped_listing_submitters to authenticated;

drop policy if exists "admins read listing submitter emails"
  on public.scraped_listing_submitters;
create policy "admins read listing submitter emails"
  on public.scraped_listing_submitters for select to authenticated
  using ((select public.is_admin()));

insert into public.scraped_listing_submitters (listing_id, email)
select id, parsed_data->>'submitted_by_email'
from public.scraped_listings
where jsonb_typeof(parsed_data->'submitted_by_email') = 'string'
  and btrim(parsed_data->>'submitted_by_email') <> ''
on conflict (listing_id) do nothing;

update public.scraped_listings
set parsed_data = parsed_data - 'submitted_by_email'
where jsonb_typeof(parsed_data) = 'object'
  and parsed_data ? 'submitted_by_email';

-- Older builds may still send the email. Never persist it in the public payload.
create or replace function public.strip_listing_submitter_email()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if jsonb_typeof(new.parsed_data) = 'object' then
    new.parsed_data := new.parsed_data - 'submitted_by_email';
  end if;
  return new;
end;
$$;

revoke execute on function public.strip_listing_submitter_email()
  from public, anon, authenticated;

drop trigger if exists strip_listing_submitter_email on public.scraped_listings;
create trigger strip_listing_submitter_email
  before insert or update of parsed_data on public.scraped_listings
  for each row execute function public.strip_listing_submitter_email();

-- Read the email from the account record after the parent row exists.
create or replace function public.save_listing_submitter_email()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.scraped_listing_submitters (listing_id, email)
  select new.id, email
  from auth.users
  where id = new.created_by and email is not null and btrim(email) <> '';

  return new;
end;
$$;

revoke execute on function public.save_listing_submitter_email()
  from public, anon, authenticated;

drop trigger if exists save_listing_submitter_email on public.scraped_listings;
create trigger save_listing_submitter_email
  after insert on public.scraped_listings
  for each row
  when (new.parsed_data @> '{"client_submission": true}'::jsonb)
  execute function public.save_listing_submitter_email();

notify pgrst, 'reload schema';

commit;
