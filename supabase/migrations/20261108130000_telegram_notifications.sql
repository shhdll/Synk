-- Telegram notifications for iPhones without native push. The app gets a
-- one-time code from telegram_link_code() and opens the Synk bot with it.
-- When the user taps Start, the telegram-webhook function saves their chat
-- id here. Users can see and remove their own link but never set a chat id.
--
-- Safe to run again.

begin;

create table if not exists public.telegram_links (
  user_id uuid primary key references public.users(id) on delete cascade,
  chat_id bigint unique,
  language text not null default 'en' check (language in ('en', 'ar')),
  link_code text unique,
  link_code_expires_at timestamptz,
  linked_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.telegram_links enable row level security;

drop policy if exists "Users read their own telegram link"
  on public.telegram_links;
create policy "Users read their own telegram link"
  on public.telegram_links for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users remove their own telegram link"
  on public.telegram_links;
create policy "Users remove their own telegram link"
  on public.telegram_links for delete
  to authenticated
  using (auth.uid() = user_id);

revoke all on public.telegram_links from public, anon, authenticated;
grant select, delete on public.telegram_links to authenticated;
grant select, insert, update, delete on public.telegram_links to service_role;

-- New code each time, valid for 15 minutes. Keeps an existing chat id, so
-- asking for a code never disconnects anyone.
create or replace function public.telegram_link_code(p_language text default 'en')
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_code text := replace(gen_random_uuid()::text, '-', '');
  v_language text := case when p_language = 'ar' then 'ar' else 'en' end;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  insert into public.telegram_links (
    user_id, language, link_code, link_code_expires_at
  )
  values (v_user_id, v_language, v_code, now() + interval '15 minutes')
  on conflict (user_id) do update
  set language = excluded.language,
      link_code = excluded.link_code,
      link_code_expires_at = excluded.link_code_expires_at,
      updated_at = now();

  return v_code;
end;
$$;

revoke all on function public.telegram_link_code(text) from public, anon;
grant execute on function public.telegram_link_code(text) to authenticated;

commit;
