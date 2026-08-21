drop policy if exists "clients submit listings for review" on public.scraped_listings;
create policy "clients submit listings for review"
  on public.scraped_listings for insert to authenticated
  with check (
    created_by = auth.uid()
    and status = 'pending_review'
    and property_type in ('room', 'house', 'apartment')
    and coalesce((parsed_data->>'client_submission')::boolean, false)
  );

drop policy if exists "clients read own submissions" on public.scraped_listings;
create policy "clients read own submissions"
  on public.scraped_listings for select to authenticated
  using (created_by = auth.uid() or public.is_admin());
