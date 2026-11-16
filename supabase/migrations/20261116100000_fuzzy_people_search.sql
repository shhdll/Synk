-- People search forgives typos: "shahd" finds "shahad", "sarha" finds
-- "Sarah". Exact and starting matches still come first. Typos are only
-- tried for searches of 4 letters or more, like the app's own search.
-- Blocked, suspended and other-gender users stay hidden through
-- users_blocked_either_way. Safe to run again.

begin;

create extension if not exists pg_trgm with schema extensions;

create or replace function public.search_users(
  search_query text,
  result_limit integer default 20
)
returns table (
  id uuid,
  full_name text,
  username text,
  avatar_url text,
  gender text
)
language sql
stable
security definer
set search_path = ''
as $$
  with q as (
    select
      lower(ltrim(trim(coalesce(search_query, '')), '@')) as raw,
      replace(replace(replace(
        lower(ltrim(trim(coalesce(search_query, '')), '@')),
        '\', '\\'), '%', '\%'), '_', '\_') as term
  ),
  matches as (
    select
      u.id, u.full_name, u.username, u.avatar_url, u.gender,
      lower(u.username) as lower_username,
      lower(coalesce(u.full_name, '')) as lower_name,
      greatest(
        extensions.word_similarity(q.raw, lower(coalesce(u.username, ''))),
        extensions.word_similarity(q.raw, lower(coalesce(u.full_name, '')))
      ) as closeness,
      q.raw, q.term
    from public.users u, q
    where auth.uid() is not null
      and length(q.raw) > 0
      and u.id <> auth.uid()
      and private.same_gender(auth.uid(), u.id)
      and not public.users_blocked_either_way(auth.uid(), u.id)
  )
  select m.id, m.full_name, m.username, m.avatar_url, m.gender
  from matches m
  where m.lower_username like m.term || '%'
     or m.lower_name like '%' || m.term || '%'
     or (length(m.raw) >= 4 and m.closeness >= 0.5)
  order by
    (m.lower_username = m.raw) desc,
    (m.lower_username like m.term || '%') desc,
    (m.lower_name like '%' || m.term || '%') desc,
    m.closeness desc,
    lower(coalesce(m.full_name, m.username, ''))
  limit least(greatest(coalesce(result_limit, 20), 1), 50);
$$;

revoke all on function public.search_users(text, integer) from public, anon;
grant execute on function public.search_users(text, integer) to authenticated;

commit;
