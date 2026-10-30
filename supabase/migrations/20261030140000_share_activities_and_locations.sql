-- Sharing activities and locations in chats.
--
-- chat_messages.kind says what a message is: 'text', 'photo', 'activity' or
-- 'location'.
-- * An activity message points at the activity and keeps a snapshot of its
--   title, time, place and photo for the card, so the card still shows if
--   the activity changes or is deleted (shared_activity_id is then null).
--   It can only be sent when everyone in the chat can see the activity:
--   already in it, or shown it by the Home feed (public, and the same gender
--   as the host, matching get_discovery_feed).
-- * A location message has coordinates plus an optional name and address.

begin;

alter table public.chat_messages
  add column if not exists kind text not null default 'text',
  add column if not exists shared_activity_id uuid
    references public.activities (id) on delete set null,
  add column if not exists shared_activity jsonb,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists location_name text,
  add column if not exists location_address text;

update public.chat_messages
set kind = 'photo'
where image_path is not null and kind = 'text';

alter table public.chat_messages
  drop constraint if exists chat_messages_kind_check;
alter table public.chat_messages
  add constraint chat_messages_kind_check
  check (kind in ('text', 'photo', 'activity', 'location'));

-- Activity and location messages have no text of their own.
alter table public.chat_messages
  drop constraint if exists chat_messages_body_or_image;
alter table public.chat_messages
  add constraint chat_messages_body_or_image check (
    length(body) <= 2000
    and (
      deleted_at is not null
      or image_path is not null
      or kind in ('activity', 'location')
      or length(trim(body)) >= 1
    )
  );

-- Whether [viewer] may see the activity: they host it, are in it (joined or
-- waitlisted), or the Home feed would show it to them.
create or replace function public.can_see_activity(target_activity_id uuid, viewer uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.activities a
    left join public.users h on h.id = a.host_id
    left join public.users v on v.id = viewer
    where a.id = target_activity_id
      and (
        a.host_id = viewer
        or exists (
          select 1 from public.activity_participants ap
          where ap.activity_id = a.id
            and ap.user_id = viewer
            and ap.status in ('joined', 'waitlisted')
        )
        or (
          a.is_public
          and coalesce(lower(trim(h.gender)), '') <> ''
          and lower(trim(h.gender)) = lower(trim(v.gender))
        )
      )
  );
$$;

revoke all on function public.can_see_activity(uuid, uuid) from public, anon, authenticated;

-- Replaced by the version that can share activities and locations.
drop function if exists public.send_chat_message(uuid, text, text);

create or replace function public.send_chat_message(
  target_chat_id uuid,
  message_body text default '',
  image_path text default null,
  shared_activity_id uuid default null,
  latitude double precision default null,
  longitude double precision default null,
  location_name text default null,
  location_address text default null
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
    where id = target_chat.activity_id and ends_at <= now()
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
    chat_id, sender_id, body, image_path, kind,
    shared_activity_id, shared_activity,
    latitude, longitude, location_name, location_address
  )
  values (
    target_chat_id, me, cleaned, photo, message_kind,
    shared_activity_id, snapshot,
    case when has_location then latitude end,
    case when has_location then longitude end,
    case when has_location then nullif(trim(coalesce(location_name, '')), '') end,
    case when has_location then nullif(trim(coalesce(location_address, '')), '') end
  )
  returning * into new_message;

  return jsonb_build_object(
    'result', 'sent',
    'message', jsonb_build_object(
      'id', new_message.id,
      'chat_id', new_message.chat_id,
      'sender_id', new_message.sender_id,
      'body', new_message.body,
      'image_path', new_message.image_path,
      'kind', new_message.kind,
      'shared_activity_id', new_message.shared_activity_id,
      'shared_activity', new_message.shared_activity,
      'latitude', new_message.latitude,
      'longitude', new_message.longitude,
      'location_name', new_message.location_name,
      'location_address', new_message.location_address,
      'created_at', new_message.created_at
    )
  );
end;
$$;

revoke all on function public.send_chat_message(uuid, text, text, uuid, double precision, double precision, text, text) from public, anon;
grant execute on function public.send_chat_message(uuid, text, text, uuid, double precision, double precision, text, text) to authenticated;

-- Also clears a shared activity or location.
create or replace function public.delete_chat_message(target_message_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.require_signed_in();
  old_photo text;
begin
  select image_path into old_photo
  from public.chat_messages
  where id = target_message_id and sender_id = me and deleted_at is null
  for update;

  if not found then
    return jsonb_build_object('result', 'not_found');
  end if;

  update public.chat_messages
  set deleted_at = now(), body = '', image_path = null,
      shared_activity_id = null, shared_activity = null,
      latitude = null, longitude = null,
      location_name = null, location_address = null
  where id = target_message_id;

  return jsonb_build_object('result', 'deleted', 'image_path', old_photo);
end;
$$;

-- Adds last_message_kind and last_message_label (the activity's title or the
-- place's name), so a new return type: replaced rather than altered.
drop function if exists public.get_my_chats();

create or replace function public.get_my_chats()
returns table (
  chat_id uuid,
  kind text,
  activity_id uuid,
  activity_title text,
  activity_starts_at timestamptz,
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
    a.photo_url,
    a.category_label,
    a.category_emoji,
    (select count(*)::int from public.chat_members m where m.chat_id = c.id),
    other.id,
    other.full_name,
    other.username,
    other.avatar_url,
    other.gender,
    last_msg.body,
    last_msg.sender_id,
    coalesce(nullif(trim(sender.full_name), ''), sender.username),
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
    select msg.body, msg.sender_id, msg.deleted_at, msg.image_path,
      msg.kind, msg.shared_activity, msg.location_name
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
  where me.user_id = auth.uid()
    -- Finished, but the cron job hasn't deleted it yet.
    and (c.kind = 'direct' or a.ends_at > now())
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
