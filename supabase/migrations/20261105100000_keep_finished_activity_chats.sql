-- Activity chats stay after the activity, read only.
--
-- Before, a finished activity's chat was hidden and a cron job deleted it
-- with its messages. Now:
--   * the chat and its messages stay, and get_my_chats lists it, with the
--     activity's end time so the app can show it as closed
--   * sending still works for a day after the activity ends, then
--     send_chat_message returns 'finished'
--   * sync_activity_chat leaves a finished activity's chat as it is
-- Chats the cron job already deleted don't come back.
--
-- Safe to run again.

begin;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'delete-finished-activity-chats') then
    perform cron.unschedule('delete-finished-activity-chats');
  end if;
end;
$$;

drop function if exists public.delete_finished_activity_chats();

-- A finished activity keeps its chat and members. Otherwise unchanged from
-- 20261029130000_close_finished_activity_chats.sql.
create or replace function public.sync_activity_chat(target_activity_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_chat_id uuid;
begin
  if not exists (select 1 from public.activities where id = target_activity_id) then
    return;
  end if;

  -- A finished activity's chat stays as it was.
  if exists (
    select 1 from public.activities
    where id = target_activity_id and ends_at <= now()
  ) then
    return;
  end if;

  insert into public.chats (kind, activity_id)
  values ('activity', target_activity_id)
  on conflict (activity_id) do nothing;

  select id into target_chat_id
  from public.chats
  where activity_id = target_activity_id;

  with wanted as (
    select a.host_id as user_id
    from public.activities a
    where a.id = target_activity_id and a.host_id is not null
    union
    select ap.user_id
    from public.activity_participants ap
    where ap.activity_id = target_activity_id and ap.status = 'joined'
  )
  insert into public.chat_members (chat_id, user_id)
  select target_chat_id, w.user_id
  from wanted w
  join public.users u on u.id = w.user_id
  on conflict do nothing;

  delete from public.chat_members cm
  where cm.chat_id = target_chat_id
    and not exists (
      select 1 from public.activities a
      where a.id = target_activity_id and a.host_id = cm.user_id
    )
    and not exists (
      select 1 from public.activity_participants ap
      where ap.activity_id = target_activity_id
        and ap.user_id = cm.user_id
        and ap.status = 'joined'
    );
end;
$$;

-- Sending stops a day after the activity ends. Otherwise unchanged from
-- 20261104150000_encrypt_chat_messages.sql.
create or replace function public.send_chat_message(
  target_chat_id uuid,
  message_body text default '',
  image_path text default null,
  shared_activity_id uuid default null,
  latitude double precision default null,
  longitude double precision default null,
  location_name text default null,
  location_address text default null,
  reply_to_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.require_signed_in();
  target_chat public.chats;
  other_id uuid;
  cleaned text := trim(coalesce(message_body, ''));
  photo text := nullif(trim(coalesce(image_path, '')), '');
  has_location boolean := latitude is not null or longitude is not null;
  message_kind text;
  snapshot jsonb;
  new_message public.chat_messages;
begin
  -- A reply must point at a message in the same chat.
  if send_chat_message.reply_to_id is not null and not exists (
    select 1 from public.chat_messages r
    where r.id = send_chat_message.reply_to_id and r.chat_id = target_chat_id
  ) then
    return jsonb_build_object('result', 'invalid');
  end if;

  -- One kind per message: an activity, a location, a photo, or text.
  if (shared_activity_id is not null)::int + has_location::int + (photo is not null)::int > 1
     or length(cleaned) > 2000
     or (length(cleaned) = 0 and photo is null and shared_activity_id is null and not has_location)
     or (has_location and (
       latitude is null or longitude is null
       or latitude not between -90 and 90
       or longitude not between -180 and 180
     )) then
    return jsonb_build_object('result', 'invalid');
  end if;

  message_kind := case
    when shared_activity_id is not null then 'activity'
    when has_location then 'location'
    when photo is not null then 'photo'
    else 'text'
  end;

  if not public.is_chat_member(target_chat_id) then
    return jsonb_build_object('result', 'not_member');
  end if;

  -- Only a photo you uploaded into this chat's folder.
  if photo is not null and not exists (
    select 1 from storage.objects o
    where o.bucket_id = 'chat-photos'
      and o.name = photo
      and (storage.foldername(o.name))[1] = target_chat_id::text
      and o.owner = me
  ) then
    return jsonb_build_object('result', 'invalid');
  end if;

  select * into target_chat from public.chats where id = target_chat_id;

  if target_chat.kind = 'activity' and exists (
    select 1 from public.activities
    where id = target_chat.activity_id and ends_at + interval '1 day' <= now()
  ) then
    return jsonb_build_object('result', 'finished');
  end if;

  if target_chat.kind = 'direct' then
    other_id := case when target_chat.user_a = me then target_chat.user_b else target_chat.user_a end;
    if not exists (
      select 1 from public.friendships
      where user_a = target_chat.user_a and user_b = target_chat.user_b
    ) or exists (
      select 1 from public.user_blocks
      where (blocker_id = me and blocked_id = other_id)
         or (blocker_id = other_id and blocked_id = me)
    ) then
      return jsonb_build_object('result', 'not_friends');
    end if;
  end if;

  if shared_activity_id is not null then
    -- You must be able to see it, and so must everyone you're sending it
    -- to: already in it, or shown it by the Home feed (public, same gender
    -- as the host).
    if not public.can_see_activity(shared_activity_id, me) then
      return jsonb_build_object('result', 'invalid');
    end if;
    if exists (
      select 1 from public.chat_members m
      where m.chat_id = target_chat_id
        and m.user_id <> me
        and not public.can_see_activity(shared_activity_id, m.user_id)
    ) then
      return jsonb_build_object('result', 'not_visible_to_all');
    end if;

    -- Shown on the card even if the activity changes or is deleted later.
    select jsonb_build_object(
      'title', a.title,
      'starts_at', a.starts_at,
      'ends_at', a.ends_at,
      'location_name', a.location_name,
      'photo_url', a.photo_url,
      'category_label', a.category_label,
      'category_emoji', a.category_emoji
    )
    into snapshot
    from public.activities a
    where a.id = shared_activity_id;
  end if;

  insert into public.chat_messages (
    chat_id, sender_id, body_encrypted, image_path, kind,
    shared_activity_id, shared_activity,
    latitude, longitude, location_name, location_address, reply_to_id
  )
  values (
    target_chat_id, me, public.encrypt_chat_body(cleaned), photo, message_kind,
    shared_activity_id, snapshot,
    case when has_location then latitude end,
    case when has_location then longitude end,
    case when has_location then nullif(trim(coalesce(location_name, '')), '') end,
    case when has_location then nullif(trim(coalesce(location_address, '')), '') end,
    reply_to_id
  )
  returning * into new_message;

  return jsonb_build_object(
    'result', 'sent',
    'message', jsonb_build_object(
      'id', new_message.id,
      'chat_id', new_message.chat_id,
      'sender_id', new_message.sender_id,
      'body', cleaned,
      'image_path', new_message.image_path,
      'kind', new_message.kind,
      'shared_activity_id', new_message.shared_activity_id,
      'shared_activity', new_message.shared_activity,
      'latitude', new_message.latitude,
      'longitude', new_message.longitude,
      'location_name', new_message.location_name,
      'location_address', new_message.location_address,
      'reply_to_id', new_message.reply_to_id,
      'created_at', new_message.created_at
    )
  );
end;
$$;

revoke all on function public.send_chat_message(uuid, text, text, uuid, double precision, double precision, text, text, uuid) from public, anon;
grant execute on function public.send_chat_message(uuid, text, text, uuid, double precision, double precision, text, text, uuid) to authenticated;

-- Lists finished activity chats too, with activity_ends_at. A new column,
-- so the function is dropped and made again. Otherwise unchanged from
-- 20261104180000_block_chats.sql.
drop function if exists public.get_my_chats();

create function public.get_my_chats()
returns table (
  chat_id uuid,
  kind text,
  activity_id uuid,
  activity_title text,
  activity_starts_at timestamptz,
  activity_ends_at timestamptz,
  activity_photo_url text,
  activity_category_label text,
  activity_category_emoji text,
  member_count integer,
  other_user_id uuid,
  other_full_name text,
  other_username text,
  other_avatar_url text,
  other_gender text,
  last_message_body text,
  last_message_sender_id uuid,
  last_message_sender_name text,
  last_message_sender_hidden boolean,
  last_message_at timestamptz,
  last_message_is_deleted boolean,
  last_message_has_photo boolean,
  last_message_kind text,
  last_message_label text,
  unread_count integer,
  is_muted boolean,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    c.id,
    c.kind,
    a.id,
    a.title,
    a.starts_at,
    a.ends_at,
    a.photo_url,
    a.category_label,
    a.category_emoji,
    (select count(*)::int from public.chat_members m where m.chat_id = c.id),
    other.id,
    other.full_name,
    other.username,
    other.avatar_url,
    other.gender,
    case when last_msg.id is not null
      then coalesce(public.decrypt_chat_body(last_msg.body_encrypted), '')
    end,
    case when sender_hidden.hidden
      then private.chat_stand_in_id(c.id, last_msg.sender_id)
      else last_msg.sender_id end,
    case when sender_hidden.hidden then null
      else coalesce(nullif(trim(sender.full_name), ''), sender.username) end,
    sender_hidden.hidden,
    c.last_message_at,
    last_msg.deleted_at is not null,
    last_msg.image_path is not null,
    last_msg.kind,
    coalesce(last_msg.shared_activity ->> 'title', last_msg.location_name),
    (
      select count(*)::int
      from public.chat_messages msg
      where msg.chat_id = c.id
        and msg.created_at > me.last_read_at
        and msg.sender_id is distinct from auth.uid()
        and msg.deleted_at is null
        and not exists (
          select 1 from public.chat_hidden_messages h
          where h.message_id = msg.id and h.user_id = auth.uid()
        )
    ),
    me.muted,
    c.created_at
  from public.chat_members me
  join public.chats c on c.id = me.chat_id
  left join public.activities a on a.id = c.activity_id
  left join public.users other
    on c.kind = 'direct'
   and other.id = case when c.user_a = auth.uid() then c.user_b else c.user_a end
  left join lateral (
    select msg.id, msg.body_encrypted, msg.sender_id, msg.deleted_at,
      msg.image_path, msg.kind, msg.shared_activity, msg.location_name
    from public.chat_messages msg
    where msg.chat_id = c.id
      and (me.cleared_at is null or msg.created_at > me.cleared_at)
      and not exists (
        select 1 from public.chat_hidden_messages h
        where h.message_id = msg.id and h.user_id = auth.uid()
      )
    order by msg.created_at desc
    limit 1
  ) last_msg on true
  left join public.users sender on sender.id = last_msg.sender_id
  cross join lateral (
    select coalesce(
      last_msg.sender_id <> auth.uid() and private.blocked_me(last_msg.sender_id),
      false
    ) as hidden
  ) sender_hidden
  where me.user_id = auth.uid()
    -- Deleted for you, and nothing new since.
    and (
      me.cleared_at is null
      or coalesce(c.last_message_at, c.created_at) > me.cleared_at
    )
    and (
      c.kind = 'activity'
      or not exists (
        select 1 from public.user_blocks b
        where (b.blocker_id = auth.uid() and b.blocked_id = other.id)
           or (b.blocker_id = other.id and b.blocked_id = auth.uid())
      )
    )
  order by coalesce(c.last_message_at, c.created_at) desc;
$$;

revoke all on function public.get_my_chats() from public, anon;
grant execute on function public.get_my_chats() to authenticated;

commit;
