-- Lets the app check that the signed-in account still exists and isn't
-- suspended. A saved session keeps working until its token expires, so
-- without this a deleted or suspended user stays in the app.

begin;

create or replace function public.my_account_status()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when auth.uid() is null then 'signed_out'
    when not exists (select 1 from auth.users where id = auth.uid()) then 'deleted'
    when exists (select 1 from private.user_suspensions where user_id = auth.uid()) then 'suspended'
    else 'ok'
  end;
$$;

revoke all on function public.my_account_status() from public, anon;
grant execute on function public.my_account_status() to authenticated;

commit;
