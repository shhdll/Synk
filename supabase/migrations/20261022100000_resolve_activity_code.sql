create or replace function public.resolve_activity_code(entered_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  selected_activity public.activities%rowtype;
begin
  if auth.uid() is null then raise exception 'You must be signed in.'; end if;
  if entered_code is null or trim(entered_code) !~ '^[0-9]{6}$' then
    return jsonb_build_object('found', false);
  end if;
  select * into selected_activity from public.activities
    where activity_code = trim(entered_code);
  if not found or selected_activity.starts_at <= now()
      or selected_activity.host_id = auth.uid() then
    return jsonb_build_object('found', false);
  end if;
  return jsonb_build_object(
    'found', true,
    'activity', to_jsonb(selected_activity) - 'activity_code'
  );
end;
$$;

revoke all on function public.resolve_activity_code(text) from public;
grant execute on function public.resolve_activity_code(text) to authenticated;
