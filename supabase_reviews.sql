-- Run this script in the Supabase SQL Editor.
-- Public visitors may read and submit reviews. Only an authenticated user
-- whose app_metadata.role is "admin" may delete them.

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 50),
  rating smallint not null check (rating between 1 and 5),
  comment text not null check (char_length(btrim(comment)) between 1 and 600),
  created_at timestamptz not null default now()
);

create index if not exists reviews_created_at_idx
  on public.reviews (created_at desc);

alter table public.reviews enable row level security;

grant usage on schema public to anon, authenticated;
revoke all on table public.reviews from anon, authenticated;
grant select, insert on table public.reviews to anon, authenticated;
grant delete on table public.reviews to authenticated;

drop policy if exists "Reviews are viewable by everyone" on public.reviews;
create policy "Reviews are viewable by everyone"
  on public.reviews
  for select
  to anon, authenticated
  using (true);

drop policy if exists "Visitors can submit reviews" on public.reviews;
create policy "Visitors can submit reviews"
  on public.reviews
  for insert
  to anon, authenticated
  with check (
    char_length(btrim(name)) between 1 and 50
    and rating between 1 and 5
    and char_length(btrim(comment)) between 1 and 600
  );

drop policy if exists "Admins can delete reviews" on public.reviews;
create policy "Admins can delete reviews"
  on public.reviews
  for delete
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

create or replace function public.get_review_summary()
returns table (review_count bigint, average_rating numeric)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    count(*) as review_count,
    coalesce(round(avg(reviews.rating)::numeric, 1), 0)::numeric as average_rating
  from public.reviews as reviews;
$$;

revoke all on function public.get_review_summary() from public;
grant execute on function public.get_review_summary() to anon, authenticated;

-- Assign {"role":"admin"} to the user's app_metadata in Supabase Auth.
-- Never place a service_role key in this website.
