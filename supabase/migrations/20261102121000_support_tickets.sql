-- Messages sent from Settings > Contact support. Only the submit-support
-- edge function writes here; the team reads them in the dashboard.
begin;

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete set null,
  email text not null,
  category text not null check (category in ('problem', 'feedback', 'other')),
  message text not null check (char_length(btrim(message)) between 10 and 2000),
  app_version text,
  status text not null default 'open'
    check (status in ('open', 'replied', 'closed')),
  created_at timestamptz not null default now()
);

create index if not exists support_tickets_user_created_idx
  on public.support_tickets (user_id, created_at desc);

alter table public.support_tickets enable row level security;
revoke all on public.support_tickets from public, anon, authenticated;
grant select, insert, delete on public.support_tickets to service_role;

commit;
