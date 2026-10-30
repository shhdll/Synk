-- Photos in chats.
--
-- A message can now be a photo, with or without text. Photos live in the
-- private chat-photos bucket at <chat_id>/<file>: only the chat's members
-- can upload there or read them, and the app shows them through short-lived
-- signed URLs. A photo message's body is '' (get_my_chats shows that as the
-- last message, which the app labels "Photo").

begin;

alter table public.chat_messages
  add column if not exists image_path text;

alter table public.chat_messages
  alter column body set default '';

-- Text is optional when there's a photo.
alter table public.chat_messages
  drop constraint if exists chat_messages_body_check;
alter table public.chat_messages
  drop constraint if exists chat_messages_body_or_image;
alter table public.chat_messages
  add constraint chat_messages_body_or_image check (
    length(body) <= 2000
    and (image_path is not null or length(trim(body)) >= 1)
  );

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'chat-photos',
  'chat-photos',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/heic', 'image/webp']
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Takes the folder as text, so a file in another bucket whose folder isn't
-- a chat id can't make the policy fail.
create or replace function public.is_chat_member_folder(folder text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.chat_members
    where chat_id::text = folder and user_id = auth.uid()
  );
$$;

revoke all on function public.is_chat_member_folder(text) from public, anon;
grant execute on function public.is_chat_member_folder(text) to authenticated;

drop policy if exists "chat-photos: members read" on storage.objects;
drop policy if exists "chat-photos: members upload" on storage.objects;

create policy "chat-photos: members read"
on storage.objects for select
to authenticated
using (
  bucket_id = 'chat-photos'
  and public.is_chat_member_folder((storage.foldername(name))[1])
);

create policy "chat-photos: members upload"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'chat-photos'
  and public.is_chat_member_folder((storage.foldername(name))[1])
);

-- Replaced by the version with image_path below.
drop function if exists public.send_chat_message(uuid, text);

create or replace function public.send_chat_message(
  target_chat_id uuid,
  message_body text default '',
  image_path text default null
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
  new_message public.chat_messages;
begin
  if (length(cleaned) = 0 and photo is null) or length(cleaned) > 2000 then
    return jsonb_build_object('result', 'invalid');
  end if;

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

  insert into public.chat_messages (chat_id, sender_id, body, image_path)
  values (target_chat_id, me, cleaned, photo)
  returning * into new_message;

  return jsonb_build_object(
    'result', 'sent',
    'message', jsonb_build_object(
      'id', new_message.id,
      'chat_id', new_message.chat_id,
      'sender_id', new_message.sender_id,
      'body', new_message.body,
      'image_path', new_message.image_path,
      'created_at', new_message.created_at
    )
  );
end;
$$;

revoke all on function public.send_chat_message(uuid, text, text) from public, anon;
grant execute on function public.send_chat_message(uuid, text, text) to authenticated;

commit;
