-- Chat message text is stored encrypted.
--
-- chat_messages.body is replaced by body_encrypted: the text encrypted with
-- AES-256 (pgcrypto) using the 'chat_message_key' secret in Vault. Database
-- dumps, backups and the table editor only show ciphertext; the functions
-- below decrypt it for chat members.
--
-- The key is created here and never leaves the database. Keep a copy
-- somewhere safe: without it every message is unreadable.
--   select decrypted_secret from vault.decrypted_secrets
--   where name = 'chat_message_key';
--
-- Realtime still delivers new rows, but only the ciphertext, so the app
-- loads each new message through get_chat_messages.
--
-- Push previews are queued in plain text for the push function and cleared
-- once the notification is processed.

begin;

create extension if not exists pgcrypto with schema extensions;

do $$
begin
  if not exists (select 1 from vault.secrets where name = 'chat_message_key') then
    perform vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'base64'),
      'chat_message_key',
      'Encrypts chat message text. Without it every message is unreadable.'
    );
  end if;
end;
$$;

create or replace function public.chat_message_key()
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  key text;
begin
  select decrypted_secret into key
  from vault.decrypted_secrets
  where name = 'chat_message_key'
  limit 1;

  if key is null then
    raise exception 'chat_message_key is missing from Vault';
  end if;
  return key;
end;
$$;

-- Null for empty text. The key is random, so no slow key stretching.
create or replace function public.encrypt_chat_body(plain text)
returns bytea
language sql
volatile
security definer
set search_path = ''
as $$
  select case when coalesce(plain, '') = '' then null
    else extensions.pgp_sym_encrypt(
      plain, public.chat_message_key(), 'cipher-algo=aes256, s2k-mode=1'
    )
  end;
$$;

create or replace function public.decrypt_chat_body(secret bytea)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case when secret is null then null
    else extensions.pgp_sym_decrypt(secret, public.chat_message_key())
  end;
$$;

-- Only the functions below use these.
revoke all on function public.chat_message_key() from public, anon, authenticated;
revoke all on function public.encrypt_chat_body(text) from public, anon, authenticated;
revoke all on function public.decrypt_chat_body(bytea) from public, anon, authenticated;

alter table public.chat_messages
  add column if not exists body_encrypted bytea;

update public.chat_messages
set body_encrypted = public.encrypt_chat_body(body)
where body_encrypted is null and coalesce(body, '') <> '';

alter table public.chat_messages
  drop constraint if exists chat_messages_body_or_image;

alter table public.chat_messages
  drop column if exists body;

alter table public.chat_messages
  add constraint chat_messages_body_or_image check (
    deleted_at is not null
    or image_path is not null
    or kind in ('activity', 'location')
    or body_encrypted is not null
  );

-- ---- Reading ---------------------------------------------------------------

-- The latest [max_count] messages you can read, newest first, with the text
-- decrypted. [message_ids] narrows it to those messages (for realtime).
-- Leaves out what RLS on chat_messages leaves out.
create or replace function public.get_chat_messages(
  target_chat_id uuid,
  message_ids uuid[] default null,
  max_count integer default 200
)
returns setof jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with key as (select public.chat_message_key() as value)
  select (to_jsonb(m) - 'body_encrypted') || jsonb_build_object(
    'body', coalesce(extensions.pgp_sym_decrypt(m.body_encrypted, key.value), '')
  )
  from public.chat_messages m
  cross join key
  where m.chat_id = target_chat_id
    and (message_ids is null or m.id = any (message_ids))
    and public.can_read_chat_message(m.chat_id, m.created_at)
    and not exists (
      select 1 from public.chat_hidden_messages h
      where h.message_id = m.id and h.user_id = auth.uid()
    )
  order by m.created_at desc
  limit least(greatest(coalesce(max_count, 200), 1), 500);
$$;

revoke all on function public.get_chat_messages(uuid, uuid[], integer) from public, anon;
grant execute on function public.get_chat_messages(uuid, uuid[], integer) to authenticated;

-- Same as before, with the last message decrypted.
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
    case when last_msg.id is not null
      then coalesce(public.decrypt_chat_body(last_msg.body_encrypted), '')
    end,
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

-- ---- Sending and deleting --------------------------------------------------

-- Same as before, storing the text encrypted.
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

-- Same as before, clearing the encrypted text.
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
  set deleted_at = now(), body_encrypted = null, image_path = null,
      shared_activity_id = null, shared_activity = null,
      latitude = null, longitude = null,
      location_name = null, location_address = null
  where id = target_message_id;

  return jsonb_build_object('result', 'deleted', 'image_path', old_photo);
end;
$$;

-- ---- Push notifications ----------------------------------------------------

-- Same as before, with the preview decrypted.
create or replace function public.enqueue_chat_message_notifications()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  function_url text;
  webhook_secret text;
  message_preview text;
  notification record;
begin
  if new.sender_id is null then
    return null;
  end if;

  select decrypted_secret into function_url
  from vault.decrypted_secrets
  where name = 'waitlist_promotion_function_url'
  limit 1;

  select decrypted_secret into webhook_secret
  from vault.decrypted_secrets
  where name = 'waitlist_promotion_webhook_secret'
  limit 1;

  message_preview := left(trim(coalesce(public.decrypt_chat_body(new.body_encrypted), '')), 150);

  for notification in
    insert into public.chat_message_notification_outbox (
      user_id, chat_id, message_id, activity_title, sender_name,
      is_group, message_kind, preview
    )
    select
      member.user_id,
      new.chat_id,
      new.id,
      case when chat.kind = 'activity'
        then coalesce(activity.title, 'Synk')
        else coalesce(nullif(trim(sender.full_name), ''), sender.username, 'Synk')
      end,
      coalesce(nullif(trim(sender.full_name), ''), sender.username, 'Synk'),
      chat.kind = 'activity',
      new.kind,
      message_preview
    from public.chat_members as member
    join public.chats as chat on chat.id = member.chat_id
    left join public.activities as activity on activity.id = chat.activity_id
    join public.users as sender on sender.id = new.sender_id
    where member.chat_id = new.chat_id
      and member.user_id <> new.sender_id
      and not member.muted
      and not exists (
        select 1 from public.user_blocks as block
        where (block.blocker_id = member.user_id and block.blocked_id = new.sender_id)
           or (block.blocker_id = new.sender_id and block.blocked_id = member.user_id)
      )
    returning id
  loop
    if function_url is null or webhook_secret is null then
      continue;
    end if;

    begin
      perform net.http_post(
        url := function_url,
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-waitlist-push-secret', webhook_secret
        ),
        body := jsonb_build_object(
          'event_id', notification.id,
          'event_type', 'chat_message'
        ),
        timeout_milliseconds := 5000
      );
    exception when others then
      -- Never fail sending the message because of a notification.
      raise warning 'Could not queue chat message notification: %', sqlerrm;
    end;
  end loop;

  return null;
end;
$$;

revoke all on function public.enqueue_chat_message_notifications()
  from public, anon, authenticated;

-- The push function reads the preview when it claims the row ('processing'),
-- so it's only kept until the notification is done.
create or replace function public.clear_chat_notification_preview()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status in ('sent', 'no_tokens', 'failed') then
    new.preview := '';
  end if;
  return new;
end;
$$;

revoke all on function public.clear_chat_notification_preview()
  from public, anon, authenticated;

drop trigger if exists clear_chat_notification_preview
  on public.chat_message_notification_outbox;
create trigger clear_chat_notification_preview
before update of status on public.chat_message_notification_outbox
for each row
execute function public.clear_chat_notification_preview();

update public.chat_message_notification_outbox
set preview = ''
where status in ('sent', 'no_tokens', 'failed') and preview <> '';

commit;
