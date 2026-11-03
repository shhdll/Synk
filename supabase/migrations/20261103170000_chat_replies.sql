-- Replies in chats.
--
-- A message can quote an earlier message from the same chat. If the quoted
-- message is removed the reply stays, just without the quote.

begin;

alter table public.chat_messages
  add column if not exists reply_to_id uuid
    references public.chat_messages(id) on delete set null;

-- Replaced by the version that takes reply_to_id.
drop function if exists public.send_chat_message(uuid, text, text, uuid, double precision, double precision, text, text);

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
    latitude, longitude, location_name, location_address, reply_to_id
  )
  values (
    target_chat_id, me, cleaned, photo, message_kind,
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
      'body', new_message.body,
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

commit;
