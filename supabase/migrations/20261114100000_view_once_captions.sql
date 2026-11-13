-- Captions on view-once photos.
--
-- The caption is view-once too: it's kept encrypted in its own column,
-- view_once_caption, which app users can't read from the table, and
-- open_chat_view_once hands it over when the photo is opened. The message
-- text stays empty, so the caption never shows in the chats list or in
-- notifications.
--
-- send_chat_view_once gains a caption, so it's dropped and made again.
-- Runs after 20261113100000_view_once.sql. Safe to run again.

begin;

alter table public.chat_messages
  add column if not exists view_once_caption bytea;

-- Deleting the message for everyone also deletes its caption.
create or replace function public.clear_view_once_caption()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.deleted_at is not null and old.deleted_at is null then
    new.view_once_caption := null;
  end if;
  return new;
end;
$$;

revoke all on function public.clear_view_once_caption() from public, anon, authenticated;

drop trigger if exists clear_view_once_caption on public.chat_messages;
create trigger clear_view_once_caption
before update of deleted_at on public.chat_messages
for each row
execute function public.clear_view_once_caption();

-- Same as 20261113100000_view_once.sql, plus [caption] for photos.
drop function if exists public.send_chat_view_once(uuid, text, text, text, integer, smallint[], uuid);

create or replace function public.send_chat_view_once(
  target_chat_id uuid,
  message_kind text,
  image_path text default null,
  audio_path text default null,
  audio_duration_ms integer default null,
  audio_waveform smallint[] default null,
  caption text default '',
  reply_to_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  sent jsonb;
  cleaned text := trim(coalesce(caption, ''));
begin
  if length(cleaned) > 2000 then
    return jsonb_build_object('result', 'invalid');
  end if;

  if message_kind = 'photo' and send_chat_view_once.image_path is not null then
    sent := public.send_chat_message(
      target_chat_id => target_chat_id,
      message_body => '',
      image_path => send_chat_view_once.image_path,
      reply_to_id => send_chat_view_once.reply_to_id
    );
  elsif message_kind = 'voice' and send_chat_view_once.audio_path is not null then
    sent := public.send_chat_extra_message(
      target_chat_id => target_chat_id,
      message_kind => 'voice',
      audio_path => send_chat_view_once.audio_path,
      audio_duration_ms => send_chat_view_once.audio_duration_ms,
      audio_waveform => send_chat_view_once.audio_waveform,
      reply_to_id => send_chat_view_once.reply_to_id
    );
  else
    return jsonb_build_object('result', 'invalid');
  end if;

  if sent ->> 'result' = 'sent' then
    update public.chat_messages
    set view_once = true,
        view_once_caption = case
          when message_kind = 'photo' then public.encrypt_chat_body(cleaned)
        end
    where id = (sent -> 'message' ->> 'id')::uuid;
    sent := jsonb_set(sent, '{message,view_once}', 'true'::jsonb);
  end if;
  return sent;
end;
$$;

revoke all on function public.send_chat_view_once(uuid, text, text, text, integer, smallint[], text, uuid) from public, anon;
grant execute on function public.send_chat_view_once(uuid, text, text, text, integer, smallint[], text, uuid) to authenticated;

-- Same as 20261113100000_view_once.sql, plus the caption when opened.
create or replace function public.open_chat_view_once(target_message_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.require_signed_in();
  msg public.chat_messages;
  opened timestamptz;
begin
  select * into msg
  from public.chat_messages
  where id = target_message_id and view_once and deleted_at is null;

  if not found
     or not public.is_chat_member(msg.chat_id)
     or not public.can_read_chat_message(msg.chat_id, msg.created_at)
     or msg.sender_id is not distinct from me then
    return jsonb_build_object('result', 'not_found');
  end if;

  select o.opened_at into opened
  from public.chat_view_once_opens o
  where o.message_id = msg.id and o.user_id = me;

  if opened is null then
    insert into public.chat_view_once_opens (message_id, chat_id, user_id)
    values (msg.id, msg.chat_id, me);
    if msg.kind = 'voice' then
      insert into public.chat_voice_plays (message_id, chat_id, user_id)
      values (msg.id, msg.chat_id, me)
      on conflict (message_id, user_id) do nothing;
    end if;
  elsif opened <= now() - interval '5 minutes' then
    return jsonb_build_object('result', 'already_opened');
  end if;

  return jsonb_build_object(
    'result', 'opened',
    'caption', coalesce(public.decrypt_chat_body(msg.view_once_caption), '')
  );
end;
$$;

commit;
