create or replace function public.replace_district_villages(
  target_district_id uuid,
  village_names text[]
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  final_count integer;
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  if not exists (
    select 1 from public.districts where id = target_district_id
  ) then
    raise exception 'District not found';
  end if;

  create temporary table replacement_villages (
    name text primary key,
    sort_order integer not null
  ) on commit drop;

  insert into replacement_villages (name, sort_order)
  select cleaned_name, min(source_order)::integer
  from (
    select trim(source_name) as cleaned_name, source_order
    from unnest(village_names) with ordinality as input(source_name, source_order)
  ) cleaned
  where cleaned_name <> ''
  group by cleaned_name;

  if not exists (select 1 from replacement_villages) then
    raise exception 'Village list cannot be empty';
  end if;

  delete from public.villages existing
  where existing.district_id = target_district_id
    and not exists (
      select 1 from replacement_villages replacement
      where replacement.name = existing.name
    );

  update public.villages existing
  set sort_order = replacement.sort_order,
      active = true,
      updated_at = now()
  from replacement_villages replacement
  where existing.district_id = target_district_id
    and existing.name = replacement.name;

  insert into public.villages (district_id, name, sort_order, active)
  select target_district_id, replacement.name, replacement.sort_order, true
  from replacement_villages replacement
  where not exists (
    select 1 from public.villages existing
    where existing.district_id = target_district_id
      and existing.name = replacement.name
  );

  select count(*) into final_count
  from public.villages
  where district_id = target_district_id;

  return final_count;
end;
$$;

revoke all on function public.replace_district_villages(uuid, text[]) from public;
grant execute on function public.replace_district_villages(uuid, text[])
  to authenticated;

notify pgrst, 'reload schema';
