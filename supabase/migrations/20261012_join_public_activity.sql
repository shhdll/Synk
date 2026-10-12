-- Joins a public activity from its details sheet without the activity code.
-- The code is looked up here so the join rules stay in
-- join_activity_by_code: start time, host, duplicates, and capacity.
create or replace function public.join_public_activity(
  requested_activity_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  selected_code text;
  selected_is_public boolean;
begin
  -- Only authenticated users can join activities.
  if auth.uid() is null then
    raise exception 'You must be signed in.';
  end if;

  select activity_code, is_public
  into selected_code, selected_is_public
  from public.activities
  where id = requested_activity_id;

  if not found then
    return jsonb_build_object(
      'result', 'not_found',
      'message', 'This activity was not found.'
    );
  end if;

  -- Private activities can only be joined with their code.
  if not selected_is_public then
    return jsonb_build_object(
      'result', 'private_activity',
      'message', 'This activity is private. Ask the host for its code.'
    );
  end if;

  return public.join_activity_by_code(selected_code);
end;
$$;

-- Prevent anonymous or public access to the join function.
revoke all
on function public.join_public_activity(uuid)
from public;

-- Allow signed-in users to join public activities directly.
grant execute
on function public.join_public_activity(uuid)
to authenticated;
