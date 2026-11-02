-- Push notifications for new chat messages.
--
-- Every member except the sender gets one, unless they muted the chat or
-- one of them blocked the other. Settings > Notifications > Messages turns
-- them off completely. They go through the same push function as the other
-- notifications, so ntfy topics get them too.

begin;

alter table public.notification_preferences
  add column if not exists chats boolean not null default true;

create table if not exists public.chat_message_notification_outbox (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  chat_id uuid not null references public.chats(id) on delete cascade,
  message_id uuid not null references public.chat_messages(id) on delete cascade,
  -- The activity title for group chats, the sender's name for direct chats.
  activity_title text not null,
  sender_name text not null,
  is_group boolean not null,
  message_kind text not null,
  preview text not null default '',
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'sent', 'no_tokens', 'failed')),
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

alter table public.chat_message_notification_outbox enable row level security;
revoke all on public.chat_message_notification_outbox
  from public, anon, authenticated;
grant select, update on public.chat_message_notification_outbox to service_role;

create or replace function public.enqueue_chat_message_notifications()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  function_url text;
  webhook_secret text;
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
      left(trim(coalesce(new.body, '')), 150)
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

drop trigger if exists chat_message_push on public.chat_messages;
create trigger chat_message_push
after insert on public.chat_messages
for each row
execute function public.enqueue_chat_message_notifications();

commit;
