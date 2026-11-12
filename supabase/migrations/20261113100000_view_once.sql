-- View-once photos and voice messages, like WhatsApp.
--
-- chat_messages.view_once marks a photo or voice message that each other
-- member can open one time. Opening goes through open_chat_view_once,
-- which records it in chat_view_once_opens; the file can then be fetched
-- for five minutes (time to load it), and never again. The sender can't
-- open it either. This is enforced by the storage read policies, not just
-- the app.
--
-- Sent with send_chat_view_once, which uses send_chat_message (photos) or
-- send_chat_extra_message (voice) and marks the message in the same
-- transaction, so it's never visible as an ordinary message.
-- get_chat_message_extras also returns who has opened what.
--
-- Runs after 20261112100000_stickers_voice_contacts_polls.sql.
-- Safe to run again.

begin;

alter table public.chat_messages
  add column if not exists view_once boolean not null default false;

grant select (view_once) on public.chat_messages to authenticated;

create index if not exists chat_messages_view_once_image_idx
  on public.chat_messages (image_path) where view_once;
create index if not exists chat_messages_view_once_audio_idx
  on public.chat_messages (audio_path) where view_once;

-- ---- Opens ------------------------------------------------------------------------

create table if not exists public.chat_view_once_opens (
  message_id uuid not null references public.chat_messages (id) on delete cascade,
  chat_id uuid not null references public.chats (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  opened_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

create index if not exists chat_view_once_opens_chat_idx
  on public.chat_view_once_opens (chat_id);

alter table public.chat_view_once_opens enable row level security;

-- As with votes and listens: members see that something changed (for
-- realtime), and who only through get_chat_message_extras.
revoke all on public.chat_view_once_opens from public, anon, authenticated;
grant select (message_id, chat_id, opened_at)
  on public.chat_view_once_opens to authenticated;

drop policy if exists "chat_view_once_opens: members read" on public.chat_view_once_opens;
create policy "chat_view_once_opens: members read"
on public.chat_view_once_opens for select
to authenticated
using (public.is_chat_member(chat_id));

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'chat_view_once_opens'
  ) then
    alter publication supabase_realtime add table public.chat_view_once_opens;
  end if;
end;
$$;

-- ---- Files ------------------------------------------------------------------------

-- Whether the signed-in user may fetch a chat photo or recording: anything
-- that isn't view-once, or a view-once one they opened in the last five
-- minutes.
create or replace function public.can_read_chat_file(file_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1 from public.chat_messages m
    where m.view_once
      and (m.image_path = file_name or m.audio_path = file_name)
      and not exists (
        select 1 from public.chat_view_once_opens o
        where o.message_id = m.id
          and o.user_id = auth.uid()
          and o.opened_at > now() - interval '5 minutes'
      )
  );
$$;

revoke all on function public.can_read_chat_file(text) from public, anon;
grant execute on function public.can_read_chat_file(text) to authenticated;

drop policy if exists "chat-photos: members read" on storage.objects;
create policy "chat-photos: members read"
on storage.objects for select
to authenticated
using (
  bucket_id = 'chat-photos'
  and public.is_chat_member_folder((storage.foldername(name))[1])
  and public.can_read_chat_file(name)
);

drop policy if exists "chat-voice: members read" on storage.objects;
create policy "chat-voice: members read"
on storage.objects for select
to authenticated
using (
  bucket_id = 'chat-voice'
  and public.is_chat_member_folder((storage.foldername(name))[1])
  and public.can_read_chat_file(name)
);

-- ---- Sending ----------------------------------------------------------------------

-- A view-once photo (image_path from the chat-photos bucket) or voice
-- message (audio_* from the chat-voice bucket). No caption: the text would
-- show in notifications and the chats list.
create or replace function public.send_chat_view_once(
  target_chat_id uuid,
  message_kind text,
  image_path text default null,
  audio_path text default null,
  audio_duration_ms integer default null,
  audio_waveform smallint[] default null,
  reply_to_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  sent jsonb;
begin
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
    set view_once = true
    where id = (sent -> 'message' ->> 'id')::uuid;
    sent := jsonb_set(sent, '{message,view_once}', 'true'::jsonb);
  end if;
  return sent;
end;
$$;

revoke all on function public.send_chat_view_once(uuid, text, text, text, integer, smallint[], uuid) from public, anon;
grant execute on function public.send_chat_view_once(uuid, text, text, text, integer, smallint[], uuid) to authenticated;

-- ---- Opening ----------------------------------------------------------------------

-- Opens a view-once message for you: 'opened' (fetch it now; still works
-- for five minutes, e.g. if loading failed) or 'already_opened'.
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
    -- Opening a voice message is listening to it.
    if msg.kind = 'voice' then
      insert into public.chat_voice_plays (message_id, chat_id, user_id)
      values (msg.id, msg.chat_id, me)
      on conflict (message_id, user_id) do nothing;
    end if;
  elsif opened <= now() - interval '5 minutes' then
    return jsonb_build_object('result', 'already_opened');
  end if;

  return jsonb_build_object('result', 'opened');
end;
$$;

revoke all on function public.open_chat_view_once(uuid) from public, anon;
grant execute on function public.open_chat_view_once(uuid) to authenticated;

-- ---- Extras -----------------------------------------------------------------------

-- Adds "opens": [{message_id, user_id}]. Otherwise unchanged from
-- 20261112100000_stickers_voice_contacts_polls.sql.
create or replace function public.get_chat_message_extras(target_chat_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when not public.is_chat_member(target_chat_id) then
    jsonb_build_object('votes', '[]'::jsonb, 'plays', '[]'::jsonb, 'opens', '[]'::jsonb)
  else jsonb_build_object(
    'votes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'message_id', v.message_id,
        'user_id', case
          when v.user_id <> auth.uid() and private.blocked_me(v.user_id)
            then private.chat_stand_in_id(v.chat_id, v.user_id)
          else v.user_id end,
        'option_indexes', to_jsonb(v.option_indexes)
      ))
      from public.chat_poll_votes v
      join public.chat_messages m on m.id = v.message_id
      where v.chat_id = target_chat_id
        and m.deleted_at is null
        and public.can_read_chat_message(m.chat_id, m.created_at)
    ), '[]'::jsonb),
    'plays', coalesce((
      select jsonb_agg(jsonb_build_object(
        'message_id', p.message_id,
        'user_id', case
          when p.user_id <> auth.uid() and private.blocked_me(p.user_id)
            then private.chat_stand_in_id(p.chat_id, p.user_id)
          else p.user_id end
      ))
      from public.chat_voice_plays p
      join public.chat_messages m on m.id = p.message_id
      where p.chat_id = target_chat_id
        and public.can_read_chat_message(m.chat_id, m.created_at)
    ), '[]'::jsonb),
    'opens', coalesce((
      select jsonb_agg(jsonb_build_object(
        'message_id', o.message_id,
        'user_id', case
          when o.user_id <> auth.uid() and private.blocked_me(o.user_id)
            then private.chat_stand_in_id(o.chat_id, o.user_id)
          else o.user_id end
      ))
      from public.chat_view_once_opens o
      join public.chat_messages m on m.id = o.message_id
      where o.chat_id = target_chat_id
        and public.can_read_chat_message(m.chat_id, m.created_at)
    ), '[]'::jsonb)
  ) end;
$$;

commit;
