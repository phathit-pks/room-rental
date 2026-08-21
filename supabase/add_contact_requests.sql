create table if not exists public.contact_requests (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 120),
  phone text not null check (char_length(phone) between 5 and 40),
  email text,
  message text not null check (char_length(message) between 5 and 2000),
  status text not null default 'new'
    check (status in ('new', 'contacted', 'closed')),
  created_at timestamptz not null default now()
);

alter table public.contact_requests enable row level security;

drop policy if exists "public creates contact requests"
  on public.contact_requests;
create policy "public creates contact requests"
  on public.contact_requests for insert
  to anon, authenticated
  with check (true);

drop policy if exists "admins read contact requests"
  on public.contact_requests;
create policy "admins read contact requests"
  on public.contact_requests for select
  to authenticated
  using (public.is_admin());

drop policy if exists "admins update contact requests"
  on public.contact_requests;
create policy "admins update contact requests"
  on public.contact_requests for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create index if not exists contact_requests_status_created_idx
  on public.contact_requests (status, created_at desc);

notify pgrst, 'reload schema';
