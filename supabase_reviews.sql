-- Run this script in the Supabase SQL Editor.
-- Public visitors may read and submit reviews without signing in.
-- A review can only be deleted with the private token returned when it is created.

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 50),
  rating smallint not null check (rating between 1 and 5),
  comment text not null check (char_length(btrim(comment)) between 1 and 600),
  created_at timestamptz not null default now(),
  delete_token_hash bytea
);

alter table public.reviews
  add column if not exists delete_token_hash bytea;

create index if not exists reviews_created_at_idx
  on public.reviews (created_at desc);

alter table public.reviews enable row level security;

grant usage on schema public to anon, authenticated;
revoke all on table public.reviews from public, anon, authenticated;
grant select (id, name, rating, comment, created_at)
  on table public.reviews to anon, authenticated;

drop policy if exists "Reviews are viewable by everyone" on public.reviews;
create policy "Reviews are viewable by everyone"
  on public.reviews
  for select
  to anon, authenticated
  using (true);

drop policy if exists "Visitors can submit reviews" on public.reviews;
drop policy if exists "Admins can delete reviews" on public.reviews;

create or replace function public.get_review_summary()
returns table (review_count bigint, average_rating numeric)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    count(reviews.id) as review_count,
    coalesce(round(avg(reviews.rating)::numeric, 1), 0)::numeric as average_rating
  from public.reviews as reviews;
$$;

revoke all on function public.get_review_summary() from public;
grant execute on function public.get_review_summary() to anon, authenticated;

create or replace function public.create_review(
  p_name text,
  p_rating integer,
  p_comment text
)
returns table (
  id uuid,
  name text,
  rating smallint,
  comment text,
  created_at timestamptz,
  deletion_token text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_review public.reviews%rowtype;
  v_token text;
begin
  if p_name is null or char_length(btrim(p_name)) not between 1 and 50 then
    raise exception using errcode = '22023', message = 'Nama harus berisi 1 sampai 50 karakter.';
  end if;

  if p_rating is null or p_rating not between 1 and 5 then
    raise exception using errcode = '22023', message = 'Rating harus antara 1 dan 5.';
  end if;

  if p_comment is null or char_length(btrim(p_comment)) not between 1 and 600 then
    raise exception using errcode = '22023', message = 'Komentar harus berisi 1 sampai 600 karakter.';
  end if;

  v_token := encode(extensions.gen_random_bytes(32), 'hex');

  insert into public.reviews (name, rating, comment, delete_token_hash)
  values (btrim(p_name), p_rating::smallint, btrim(p_comment), extensions.digest(v_token, 'sha256'))
  returning * into v_review;

  return query
    select v_review.id, v_review.name, v_review.rating, v_review.comment, v_review.created_at, v_token;
end;
$$;

revoke all on function public.create_review(text, integer, text) from public;
grant execute on function public.create_review(text, integer, text) to anon, authenticated;

create or replace function public.delete_review_with_token(
  p_review_id uuid,
  p_deletion_token text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_review_id is null
    or p_deletion_token is null
    or char_length(p_deletion_token) <> 64 then
    return false;
  end if;

  delete from public.reviews as review
  where review.id = p_review_id
    and review.delete_token_hash = extensions.digest(p_deletion_token, 'sha256');

  return found;
end;
$$;

revoke all on function public.delete_review_with_token(uuid, text) from public;
grant execute on function public.delete_review_with_token(uuid, text) to anon, authenticated;
