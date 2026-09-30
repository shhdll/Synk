-- =============================================================================
-- Migration: Add cancel_email_change RPC function for Supabase Auth
-- Allows authenticated users to cleanly cancel a pending email change in auth.users
-- =============================================================================

create or replace function public.cancel_email_change()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  update auth.users
  set
    email_change = '',
    email_change_token_new = '',
    email_change_token_current = '',
    email_change_confirm_status = 0
  where id = uid;
end;
$$;

grant execute on function public.cancel_email_change() to authenticated;
