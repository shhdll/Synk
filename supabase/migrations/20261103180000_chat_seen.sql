-- Seen receipts in chats.
--
-- chat_members.last_read_at already says how far each member has read, and
-- members can already read each other's rows. The chat screen now listens
-- for changes to it, so "Seen" shows up live.

begin;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'chat_members'
  ) then
    alter publication supabase_realtime add table public.chat_members;
  end if;
end;
$$;

commit;
