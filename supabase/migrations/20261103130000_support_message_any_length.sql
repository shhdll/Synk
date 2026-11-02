-- Any non-empty support message is allowed.
alter table public.support_tickets
  drop constraint if exists support_tickets_message_check;

alter table public.support_tickets
  add constraint support_tickets_message_check
  check (char_length(btrim(message)) between 1 and 2000);
