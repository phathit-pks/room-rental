create extension if not exists pgcrypto;

create type public.user_role as enum ('renter', 'owner', 'admin');
create type public.property_status as enum ('draft', 'pending', 'published', 'rejected', 'inactive');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  phone text,
  role public.user_role not null default 'renter',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.provinces (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  name_lo text,
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.districts (
  id uuid primary key default gen_random_uuid(),
  province_id uuid not null references public.provinces(id) on delete cascade,
  name text not null,
  name_lo text,
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (province_id, name)
);

create table public.villages (
  id uuid primary key default gen_random_uuid(),
  district_id uuid not null references public.districts(id) on delete cascade,
  name text not null,
  name_lo text,
  latitude double precision,
  longitude double precision,
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (district_id, name)
);

create table public.properties (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  village_id uuid references public.villages(id) on delete set null,
  title text not null,
  description text,
  property_type text not null default 'apartment',
  monthly_price numeric(14,2) not null check (monthly_price >= 0),
  bedrooms integer not null default 0 check (bedrooms >= 0),
  bathrooms integer not null default 0 check (bathrooms >= 0),
  address text,
  latitude double precision not null,
  longitude double precision not null,
  contact_phone text,
  status public.property_status not null default 'draft',
  featured boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.property_images (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id) on delete cascade,
  storage_path text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table public.amenities (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  icon text
);

create table public.property_amenities (
  property_id uuid references public.properties(id) on delete cascade,
  amenity_id uuid references public.amenities(id) on delete cascade,
  primary key (property_id, amenity_id)
);

create table public.favorites (
  user_id uuid references public.profiles(id) on delete cascade,
  property_id uuid references public.properties(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, property_id)
);

create table public.advertisements (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  active boolean not null default false,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create index districts_province_idx on public.districts(province_id);
create index villages_district_idx on public.villages(district_id);
create index properties_village_idx on public.properties(village_id);
create index properties_status_idx on public.properties(status);
create index properties_location_idx on public.properties(latitude, longitude);
create index advertisements_active_dates_idx on public.advertisements(active, starts_at, ends_at);

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', ''));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.provinces enable row level security;
alter table public.districts enable row level security;
alter table public.villages enable row level security;
alter table public.properties enable row level security;
alter table public.property_images enable row level security;
alter table public.amenities enable row level security;
alter table public.property_amenities enable row level security;
alter table public.favorites enable row level security;
alter table public.advertisements enable row level security;

create policy "public reads locations" on public.provinces for select using (active or public.is_admin());
create policy "public reads districts" on public.districts for select using (active or public.is_admin());
create policy "public reads villages" on public.villages for select using (active or public.is_admin());
create policy "admins manage provinces" on public.provinces for all using (public.is_admin()) with check (public.is_admin());
create policy "admins manage districts" on public.districts for all using (public.is_admin()) with check (public.is_admin());
create policy "admins manage villages" on public.villages for all using (public.is_admin()) with check (public.is_admin());

create policy "users read own profile" on public.profiles for select using (id = auth.uid() or public.is_admin());
create policy "users update own profile" on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());
create policy "admins manage profiles" on public.profiles for all using (public.is_admin()) with check (public.is_admin());

create policy "public reads published properties" on public.properties for select using (status = 'published' or owner_id = auth.uid() or public.is_admin());
create policy "owners create properties" on public.properties for insert with check (owner_id = auth.uid());
create policy "owners update properties" on public.properties for update using (owner_id = auth.uid() or public.is_admin()) with check (owner_id = auth.uid() or public.is_admin());
create policy "owners delete properties" on public.properties for delete using (owner_id = auth.uid() or public.is_admin());

create policy "public reads published images" on public.property_images for select using (exists (select 1 from public.properties p where p.id = property_id and (p.status = 'published' or p.owner_id = auth.uid() or public.is_admin())));
create policy "owners manage images" on public.property_images for all using (exists (select 1 from public.properties p where p.id = property_id and (p.owner_id = auth.uid() or public.is_admin()))) with check (exists (select 1 from public.properties p where p.id = property_id and (p.owner_id = auth.uid() or public.is_admin())));

create policy "public reads amenities" on public.amenities for select using (true);
create policy "admins manage amenities" on public.amenities for all using (public.is_admin()) with check (public.is_admin());
create policy "public reads property amenities" on public.property_amenities for select using (true);
create policy "owners manage property amenities" on public.property_amenities for all using (exists (select 1 from public.properties p where p.id = property_id and (p.owner_id = auth.uid() or public.is_admin()))) with check (exists (select 1 from public.properties p where p.id = property_id and (p.owner_id = auth.uid() or public.is_admin())));

create policy "users manage favorites" on public.favorites for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "public reads active ads" on public.advertisements for select using ((active and now() between starts_at and ends_at) or public.is_admin());
create policy "admins manage ads" on public.advertisements for all using (public.is_admin()) with check (public.is_admin());

insert into storage.buckets (id, name, public)
values ('property-images', 'property-images', true)
on conflict (id) do nothing;

create policy "public reads property storage" on storage.objects for select using (bucket_id = 'property-images');
create policy "authenticated uploads property storage" on storage.objects for insert to authenticated with check (bucket_id = 'property-images');
create policy "owners update property storage" on storage.objects for update to authenticated using (bucket_id = 'property-images' and owner_id = auth.uid()::text);
create policy "owners delete property storage" on storage.objects for delete to authenticated using (bucket_id = 'property-images' and owner_id = auth.uid()::text);

insert into public.amenities (name, icon) values
  ('Wi-Fi', 'wifi'),
  ('เครื่องปรับอากาศ', 'ac_unit'),
  ('ที่จอดรถ', 'local_parking'),
  ('เฟอร์นิเจอร์', 'chair'),
  ('เครื่องทำน้ำอุ่น', 'hot_tub')
on conflict (name) do nothing;
