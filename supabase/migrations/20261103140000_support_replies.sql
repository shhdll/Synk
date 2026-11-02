-- Replies written on synk.cc/support-reply.html. The token is only in the
-- team's email link, so only the inbox can open a ticket's reply page.
begin;

alter table public.support_tickets
  add column if not exists reply_token uuid not null default gen_random_uuid(),
  add column if not exists reply text
    check (reply is null or char_length(btrim(reply)) between 1 and 5000),
  add column if not exists replied_at timestamptz;

create unique index if not exists support_tickets_reply_token_idx
  on public.support_tickets (reply_token);

grant update on public.support_tickets to service_role;

commit;
