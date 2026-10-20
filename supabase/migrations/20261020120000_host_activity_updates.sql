-- Let authenticated hosts update their own activity details. This policy may
-- already exist when it was added manually before the migration was deployed.
do $$
declare
  existing_policy record;
begin
  select cmd, roles, qual, with_check
  into existing_policy
  from pg_policies
  where schemaname = 'public'
    and tablename = 'activities'
    and policyname = 'Hosts can update their activities';

  if found then
    if existing_policy.cmd <> 'UPDATE'
      or not ('authenticated' = any(existing_policy.roles))
      or position('auth.uid' in lower(coalesce(existing_policy.qual, ''))) = 0
      or position('host_id' in lower(coalesce(existing_policy.qual, ''))) = 0
      or position('auth.uid' in lower(coalesce(existing_policy.with_check, ''))) = 0
      or position('host_id' in lower(coalesce(existing_policy.with_check, ''))) = 0 then
      raise exception 'Existing host activity policy is not the expected host-scoped policy.';
    end if;
  else
    create policy "Hosts can update their activities"
    on public.activities
    for update
    to authenticated
    using (host_id = auth.uid())
    with check (host_id = auth.uid());
  end if;
end;
$$;
