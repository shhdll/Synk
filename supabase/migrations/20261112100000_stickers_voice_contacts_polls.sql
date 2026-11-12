-- Stickers, voice messages, shared friends (contacts) and polls in chats.
--
-- chat_messages.kind gains four values:
-- * 'sticker': sticker_id names a sticker from the app's built-in pack
--   (assets/sticker-pack/stickers.json). No text.
-- * 'voice': audio_path is the recording in the private chat-voice bucket
--   at <chat_id>/<file>, with its length (audio_duration_ms, at most two
--   minutes) and a loudness outline for the waveform (audio_waveform,
--   0-100 per bar). Who has listened is in chat_voice_plays.
-- * 'contact': a friend of the sender, shared_user_id plus a snapshot of
--   their name, username and photo for the card.
-- * 'poll': the text (encrypted, like every message's text) is JSON:
--   {"question": "...", "options": ["...", ...], "multiple": false}.
--   Votes are in chat_poll_votes.
--
-- These are sent with send_chat_extra_message. send_chat_message is left
-- as it is. Votes and listens are read with get_chat_message_extras, which
-- swaps in the stand-in id for anyone who blocked the viewer, as
-- get_chat_messages does for senders
-- (20261104180000_block_chats.sql).
--
-- Runs after 20261109130000_other_gender_counts_as_blocked.sql.
-- Safe to run again.

begin;

-- ---- Columns ----------------------------------------------------------------------

alter table public.chat_messages
  add column if not exists sticker_id text,
  add column if not exists audio_path text,
  add column if not exists audio_duration_ms integer,
  add column if not exists audio_waveform smallint[],
  add column if not exists shared_user_id uuid
    references public.users (id) on delete set null,
  add column if not exists shared_user jsonb;

alter table public.chat_messages
  drop constraint if exists chat_messages_kind_check;
alter table public.chat_messages
  add constraint chat_messages_kind_check check (
    kind in ('text', 'photo', 'activity', 'location',
             'sticker', 'voice', 'contact', 'poll')
  );

alter table public.chat_messages
  drop constraint if exists chat_messages_body_or_image;
alter table public.chat_messages
  add constraint chat_messages_body_or_image check (
    deleted_at is not null
    or image_path is not null
    or kind in ('activity', 'location', 'sticker', 'voice', 'contact')
    or body_encrypted is not null
  );

-- sender_id stays unreadable from the table (20261104180000_block_chats.sql);
-- the new columns are readable like the rest.
grant select (sticker_id, audio_path, audio_duration_ms, audio_waveform,
              shared_user_id, shared_user)
  on public.chat_messages to authenticated;

-- ---- Voice storage ----------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'chat-voice',
  'chat-voice',
  false,
  5242880,
  array['audio/mp4', 'audio/m4a', 'audio/x-m4a', 'audio/aac', 'audio/mpeg']
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "chat-voice: members read" on storage.objects;
drop policy if exists "chat-voice: members upload" on storage.objects;
drop policy if exists "chat-voice: owner delete" on storage.objects;

create policy "chat-voice: members read"
on storage.objects for select
to authenticated
using (
  bucket_id = 'chat-voice'
  and public.is_chat_member_folder((storage.foldername(name))[1])
);

create policy "chat-voice: members upload"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'chat-voice'
  and public.is_chat_member_folder((storage.foldername(name))[1])
);

-- A cancelled send, or deleting the message, removes the file.
create policy "chat-voice: owner delete"
on storage.objects for delete
to authenticated
using (bucket_id = 'chat-voice' and owner = auth.uid());

-- ---- Poll votes and voice listens -------------------------------------------------

-- One row per voter: the options they picked. Taking every vote back
-- leaves an empty list, so realtime only ever sends inserts and updates.
create table if not exists public.chat_poll_votes (
  message_id uuid not null references public.chat_messages (id) on delete cascade,
  chat_id uuid not null references public.chats (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  option_indexes smallint[] not null default '{}',
  voted_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

create index if not exists chat_poll_votes_chat_idx
  on public.chat_poll_votes (chat_id);

create table if not exists public.chat_voice_plays (
  message_id uuid not null references public.chat_messages (id) on delete cascade,
  chat_id uuid not null references public.chats (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  played_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

create index if not exists chat_voice_plays_chat_idx
  on public.chat_voice_plays (chat_id);

alter table public.chat_poll_votes enable row level security;
alter table public.chat_voice_plays enable row level security;

-- Members can see that something changed (for realtime) but not who did
-- it: user_id is only given out by get_chat_message_extras. Writes go
-- through the functions below.
revoke all on public.chat_poll_votes from public, anon, authenticated;
revoke all on public.chat_voice_plays from public, anon, authenticated;
grant select (message_id, chat_id, option_indexes, voted_at)
  on public.chat_poll_votes to authenticated;
grant select (message_id, chat_id, played_at)
  on public.chat_voice_plays to authenticated;

drop policy if exists "chat_poll_votes: members read" on public.chat_poll_votes;
create policy "chat_poll_votes: members read"
on public.chat_poll_votes for select
to authenticated
using (public.is_chat_member(chat_id));

drop policy if exists "chat_voice_plays: members read" on public.chat_voice_plays;
create policy "chat_voice_plays: members read"
on public.chat_voice_plays for select
to authenticated
using (public.is_chat_member(chat_id));

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'chat_poll_votes'
  ) then
    alter publication supabase_realtime add table public.chat_poll_votes;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'chat_voice_plays'
  ) then
    alter publication supabase_realtime add table public.chat_voice_plays;
  end if;
end;
$$;

-- ---- Sending ----------------------------------------------------------------------

-- Sends a sticker, voice message, contact or poll. Same rules as
-- send_chat_message (20261105100000_keep_finished_activity_chats.sql):
-- members only, activity chats close a day after the activity, direct
-- chats only between friends who haven't blocked each other.
create or replace function public.send_chat_extra_message(
  target_chat_id uuid,
  message_kind text,
  message_body text default '',
  sticker_id text default null,
  audio_path text default null,
  audio_duration_ms integer default null,
  audio_waveform smallint[] default null,
  shared_user_id uuid default null,
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
  cleaned text := '';
  poll jsonb;
  option_count integer;
  snapshot jsonb;
  new_message public.chat_messages;
begin
  if send_chat_extra_message.reply_to_id is not null and not exists (
    select 1 from public.chat_messages r
    where r.id = send_chat_extra_message.reply_to_id and r.chat_id = target_chat_id
  ) then
    return jsonb_build_object('result', 'invalid');
  end if;

  if not public.is_chat_member(target_chat_id) then
    return jsonb_build_object('result', 'not_member');
  end if;

  -- What each kind needs, and nothing it doesn't.
  if message_kind = 'sticker' then
    if send_chat_extra_message.sticker_id is null
       or send_chat_extra_message.sticker_id !~ '^[a-z0-9_-]{1,40}$' then
      return jsonb_build_object('result', 'invalid');
    end if;

  elsif message_kind = 'voice' then
    if send_chat_extra_message.audio_path is null
       or send_chat_extra_message.audio_duration_ms is null
       or send_chat_extra_message.audio_duration_ms not between 300 and 121000
       or coalesce(array_length(send_chat_extra_message.audio_waveform, 1), 0) > 100
       or exists (
         select 1 from unnest(send_chat_extra_message.audio_waveform) v
         where v is null or v not between 0 and 100
       )
       -- Only a recording you uploaded into this chat's folder.
       or not exists (
         select 1 from storage.objects o
         where o.bucket_id = 'chat-voice'
           and o.name = send_chat_extra_message.audio_path
           and (storage.foldername(o.name))[1] = target_chat_id::text
           and o.owner = me
       ) then
      return jsonb_build_object('result', 'invalid');
    end if;

  elsif message_kind = 'contact' then
    -- Your friend, and no one in the chat is in a block with them.
    if send_chat_extra_message.shared_user_id is null
       or not exists (
         select 1 from public.friendships f
         where f.user_a = least(me, send_chat_extra_message.shared_user_id)
           and f.user_b = greatest(me, send_chat_extra_message.shared_user_id)
       ) then
      return jsonb_build_object('result', 'invalid');
    end if;
    if exists (
      select 1 from public.chat_members m
      where m.chat_id = target_chat_id
        and m.user_id <> send_chat_extra_message.shared_user_id
        and public.users_blocked_either_way(m.user_id, send_chat_extra_message.shared_user_id)
    ) then
      return jsonb_build_object('result', 'not_visible_to_all');
    end if;
    select jsonb_build_object(
      'id', u.id,
      'full_name', u.full_name,
      'username', u.username,
      'avatar_url', u.avatar_url,
      'gender', u.gender
    )
    into snapshot
    from public.users u
    where u.id = send_chat_extra_message.shared_user_id;

  elsif message_kind = 'poll' then
    begin
      poll := message_body::jsonb;
    exception when others then
      return jsonb_build_object('result', 'invalid');
    end;
    -- The shape first (a missing key is null, so "is distinct from"), then
    -- the lengths, which need that shape.
    if jsonb_typeof(poll) is distinct from 'object'
       or jsonb_typeof(poll -> 'question') is distinct from 'string'
       or jsonb_typeof(poll -> 'options') is distinct from 'array' then
      return jsonb_build_object('result', 'invalid');
    end if;
    if length(trim(poll ->> 'question')) not between 1 and 300
       or jsonb_array_length(poll -> 'options') not between 2 and 12
       or exists (
         select 1 from jsonb_array_elements(poll -> 'options') o
         where jsonb_typeof(o) <> 'string'
            or length(trim(o #>> '{}')) not between 1 and 100
       ) then
      return jsonb_build_object('result', 'invalid');
    end if;
    -- Stored in a fixed shape.
    cleaned := jsonb_build_object(
      'question', trim(poll ->> 'question'),
      'options', (
        select jsonb_agg(trim(o #>> '{}') order by n)
        from jsonb_array_elements(poll -> 'options') with ordinality as t(o, n)
      ),
      'multiple', coalesce(poll -> 'multiple' = 'true'::jsonb, false)
    )::text;

  else
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

  insert into public.chat_messages (
    chat_id, sender_id, body_encrypted, kind,
    sticker_id, audio_path, audio_duration_ms, audio_waveform,
    shared_user_id, shared_user, reply_to_id
  )
  values (
    target_chat_id, me, public.encrypt_chat_body(cleaned), message_kind,
    case when message_kind = 'sticker' then send_chat_extra_message.sticker_id end,
    case when message_kind = 'voice' then send_chat_extra_message.audio_path end,
    case when message_kind = 'voice' then send_chat_extra_message.audio_duration_ms end,
    case when message_kind = 'voice' then coalesce(send_chat_extra_message.audio_waveform, '{}') end,
    case when message_kind = 'contact' then send_chat_extra_message.shared_user_id end,
    snapshot,
    send_chat_extra_message.reply_to_id
  )
  returning * into new_message;

  return jsonb_build_object(
    'result', 'sent',
    'message', (to_jsonb(new_message) - 'body_encrypted')
      || jsonb_build_object('body', cleaned)
  );
end;
$$;

revoke all on function public.send_chat_extra_message(uuid, text, text, text, text, integer, smallint[], uuid, uuid) from public, anon;
grant execute on function public.send_chat_extra_message(uuid, text, text, text, text, integer, smallint[], uuid, uuid) to authenticated;

-- ---- Votes and listens ------------------------------------------------------------

-- Your vote on a poll: the options you picked, or none to take it back.
-- Polls without "multiple" take one option.
create or replace function public.vote_chat_poll(
  target_message_id uuid,
  option_indexes smallint[]
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.require_signed_in();
  msg public.chat_messages;
  poll jsonb;
  picked smallint[];
begin
  select * into msg
  from public.chat_messages
  where id = target_message_id and kind = 'poll' and deleted_at is null;

  if not found
     or not public.is_chat_member(msg.chat_id)
     or not public.can_read_chat_message(msg.chat_id, msg.created_at) then
    return jsonb_build_object('result', 'not_found');
  end if;

  poll := public.decrypt_chat_body(msg.body_encrypted)::jsonb;
  select coalesce(array_agg(distinct i order by i), '{}') into picked
  from unnest(coalesce(vote_chat_poll.option_indexes, '{}')) i;

  if exists (
       select 1 from unnest(picked) i
       where i is null or i < 0 or i >= jsonb_array_length(poll -> 'options')
     )
     or (coalesce(array_length(picked, 1), 0) > 1
         and not coalesce(poll -> 'multiple' = 'true'::jsonb, false)) then
    return jsonb_build_object('result', 'invalid');
  end if;

  insert into public.chat_poll_votes (message_id, chat_id, user_id, option_indexes)
  values (msg.id, msg.chat_id, me, picked)
  on conflict (message_id, user_id) do update
    set option_indexes = excluded.option_indexes, voted_at = now();

  return jsonb_build_object('result', 'voted');
end;
$$;

revoke all on function public.vote_chat_poll(uuid, smallint[]) from public, anon;
grant execute on function public.vote_chat_poll(uuid, smallint[]) to authenticated;

-- You listened to someone's voice message. Your own don't count.
create or replace function public.mark_chat_voice_played(target_message_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.require_signed_in();
  msg public.chat_messages;
begin
  select * into msg
  from public.chat_messages
  where id = target_message_id and kind = 'voice' and deleted_at is null;

  if not found
     or not public.is_chat_member(msg.chat_id)
     or not public.can_read_chat_message(msg.chat_id, msg.created_at) then
    return jsonb_build_object('result', 'not_found');
  end if;

  if msg.sender_id is distinct from me then
    insert into public.chat_voice_plays (message_id, chat_id, user_id)
    values (msg.id, msg.chat_id, me)
    on conflict (message_id, user_id) do nothing;
  end if;

  return jsonb_build_object('result', 'played');
end;
$$;

revoke all on function public.mark_chat_voice_played(uuid) from public, anon;
grant execute on function public.mark_chat_voice_played(uuid) to authenticated;

-- Every poll vote and voice listen in the chat:
-- {"votes": [{message_id, user_id, option_indexes}],
--  "plays": [{message_id, user_id}]}
-- with the stand-in id for anyone who blocked you.
create or replace function public.get_chat_message_extras(target_chat_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when not public.is_chat_member(target_chat_id) then
    jsonb_build_object('votes', '[]'::jsonb, 'plays', '[]'::jsonb)
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
    ), '[]'::jsonb)
  ) end;
$$;

revoke all on function public.get_chat_message_extras(uuid) from public, anon;
grant execute on function public.get_chat_message_extras(uuid) to authenticated;

-- ---- Deleting ---------------------------------------------------------------------

-- Also clears stickers, recordings, contacts and poll votes, and returns
-- the recording's path so the app can remove the file. Otherwise unchanged
-- from 20261104150000_encrypt_chat_messages.sql.
create or replace function public.delete_chat_message(target_message_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.require_signed_in();
  old_photo text;
  old_audio text;
begin
  select image_path, audio_path into old_photo, old_audio
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
      location_name = null, location_address = null,
      sticker_id = null, audio_path = null, audio_duration_ms = null,
      audio_waveform = null, shared_user_id = null, shared_user = null
  where id = target_message_id;

  delete from public.chat_poll_votes where message_id = target_message_id;

  return jsonb_build_object(
    'result', 'deleted',
    'image_path', old_photo,
    'audio_path', old_audio
  );
end;
$$;

commit;
