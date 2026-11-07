-- Women and men never share an activity or a chat.
--
-- 20261108110000_same_gender_activity_codes.sql already stops joins by code
-- or from the sheet. This closes what was left:
--   * activities of the other gender can't be read at all, so an old link
--     opens nothing (the host still reads their own)
--   * the participants list is empty for the other gender, and never lists
--     someone of the other gender
--   * friendships between genders from before the rule are removed
--   * chat members of the other gender (to the activity host, or to the
--     other person in a direct chat) are removed, and can't be added again
--   * a message can't be sent into such a chat
-- Past participation and ratings stay as they are.
--
-- Needs private.same_gender from 20261108100000_same_gender_friends.sql.
-- Safe to run again.

begin;

-- private.same_gender isn't open to signed-in users, so policies use this.
create or replace function private.same_gender_as_me(other_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.same_gender(auth.uid(), other_user_id);
$$;

revoke all on function private.same_gender_as_me(uuid) from public, anon;
grant execute on function private.same_gender_as_me(uuid) to authenticated;

-- ---- 1. Activities ----------------------------------------------------------

drop policy if exists "Hide activities of the other gender" on public.activities;
create policy "Hide activities of the other gender"
  on public.activities
  as restrictive
  for select
  to authenticated
  using (host_id = auth.uid() or private.same_gender_as_me(host_id));

-- ---- 2. Participants list ---------------------------------------------------

-- Same as 20261104170000_block_activities.sql, plus the gender rule.
create or replace function public.get_activity_participants_list(
  p_activity_id uuid
)
returns table (
  user_id uuid,
  full_name text,
  username text,
  avatar_url text,
  gender text,
  status text,
  is_hidden boolean,
  blocked_by_me boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    case when x.hidden then null else u.id end as user_id,
    case when x.hidden then null
      else coalesce(nullif(trim(u.full_name), ''), 'Synk member') end as full_name,
    case when x.hidden then null else u.username end as username,
    case when x.hidden or x.blocked_by_me then null else u.avatar_url end as avatar_url,
    case when x.hidden or x.blocked_by_me then private.avatar_gender(u.gender)
      else u.gender end as gender,
    ap.status,
    x.hidden as is_hidden,
    x.blocked_by_me and not x.hidden as blocked_by_me
  from public.activity_participants ap
  join public.users u
    on u.id = ap.user_id
  cross join lateral (
    select
      exists (
        select 1 from public.user_blocks b
        where b.blocker_id = u.id and b.blocked_id = auth.uid()
      ) as hidden,
      exists (
        select 1 from public.user_blocks b
        where b.blocker_id = auth.uid() and b.blocked_id = u.id
      ) as blocked_by_me
  ) x
  where ap.activity_id = p_activity_id
    and ap.status = 'joined'
    and auth.uid() is not null
    and exists (
      select 1
      from public.activities a
      where a.id = p_activity_id
        and (a.host_id = auth.uid() or private.same_gender(auth.uid(), a.host_id))
        and private.same_gender(ap.user_id, a.host_id)
        and (
          a.is_public
          or a.host_id = auth.uid()
          or exists (
            select 1
            from public.activity_participants viewer
            where viewer.activity_id = a.id
              and viewer.user_id = auth.uid()
              and viewer.status in ('joined', 'waitlisted')
          )
        )
    )
  order by ap.created_at asc;
$$;

revoke all on function public.get_activity_participants_list(uuid) from public;
revoke all on function public.get_activity_participants_list(uuid) from anon;
grant execute on function public.get_activity_participants_list(uuid) to authenticated;

-- ---- 3. Friendships ---------------------------------------------------------

delete from public.friendships f
where not private.same_gender(f.user_a, f.user_b);

-- ---- 4. Chats ---------------------------------------------------------------

-- The person a member must match: the host for an activity chat, the other
-- person for a direct chat.
create or replace function private.chat_allows_member(
  target_chat_id uuid,
  member_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select case
      when c.kind = 'activity' then
        a.host_id = member_id or private.same_gender(member_id, a.host_id)
      else
        private.same_gender(c.user_a, c.user_b)
    end
    from public.chats c
    left join public.activities a on a.id = c.activity_id
    where c.id = target_chat_id
  ), true);
$$;

revoke all on function private.chat_allows_member(uuid, uuid) from public, anon, authenticated;

delete from public.chat_members m
where not private.chat_allows_member(m.chat_id, m.user_id);

create or replace function public.prevent_other_gender_chat_member()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.chat_allows_member(new.chat_id, new.user_id) then
    raise exception 'This chat is not available.';
  end if;
  return new;
end;
$$;

revoke all on function public.prevent_other_gender_chat_member() from public, anon, authenticated;

drop trigger if exists prevent_other_gender_chat_member on public.chat_members;
create trigger prevent_other_gender_chat_member
  before insert on public.chat_members
  for each row
  execute function public.prevent_other_gender_chat_member();

create or replace function public.prevent_other_gender_chat_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.sender_id is not null
     and not private.chat_allows_member(new.chat_id, new.sender_id) then
    raise exception 'This chat is not available.';
  end if;
  return new;
end;
$$;

revoke all on function public.prevent_other_gender_chat_message() from public, anon, authenticated;

drop trigger if exists prevent_other_gender_chat_message on public.chat_messages;
create trigger prevent_other_gender_chat_message
  before insert on public.chat_messages
  for each row
  execute function public.prevent_other_gender_chat_message();

commit;
