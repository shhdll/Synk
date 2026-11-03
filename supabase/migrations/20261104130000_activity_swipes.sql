-- What the user did with the For you cards (joined or opened one), so top
-- picks can learn from it later.
begin;

create table if not exists public.activity_swipes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references public.users (id) on delete cascade,
  activity_id uuid not null
    references public.activities (id) on delete cascade,
  action text not null check (action in ('join', 'open_details')),
  created_at timestamptz not null default now()
);

create index if not exists activity_swipes_user_time
  on public.activity_swipes (user_id, created_at desc);

alter table public.activity_swipes enable row level security;
revoke all on public.activity_swipes from public, anon;
grant select, insert on public.activity_swipes to authenticated;

drop policy if exists "own swipes: insert" on public.activity_swipes;
create policy "own swipes: insert" on public.activity_swipes
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "own swipes: read" on public.activity_swipes;
create policy "own swipes: read" on public.activity_swipes
  for select to authenticated using (user_id = auth.uid());

commit;
