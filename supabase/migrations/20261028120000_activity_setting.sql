-- Whether an activity happens indoors or outdoors. Existing activities stay
-- unset until their host edits them; the app requires a choice when saving.
alter table public.activities
  add column if not exists setting text
    check (setting in ('indoor', 'outdoor'));

-- Changing the setting notifies joined participants like any other detail.
create or replace function public.enqueue_activity_update_notifications()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  recipient record;
  notification_id uuid;
  function_url text;
  webhook_secret text;
begin
  if old.title is not distinct from new.title
    and old.description is not distinct from new.description
    and old.starts_at is not distinct from new.starts_at
    and old.ends_at is not distinct from new.ends_at
    and old.location_name is not distinct from new.location_name
    and old.location_address is not distinct from new.location_address
    and old.latitude is not distinct from new.latitude
    and old.longitude is not distinct from new.longitude
    and old.max_participants is not distinct from new.max_participants
    and old.is_public is not distinct from new.is_public
    and old.setting is not distinct from new.setting
    and old.photo_url is not distinct from new.photo_url then
    return new;
  end if;

  select decrypted_secret into function_url from vault.decrypted_secrets
    where name='waitlist_promotion_function_url' limit 1;
  select decrypted_secret into webhook_secret from vault.decrypted_secrets
    where name='waitlist_promotion_webhook_secret' limit 1;
  for recipient in
    select participant.user_id
    from public.activity_participants participant
    where participant.activity_id=new.id
      and participant.status='joined' and participant.user_id<>new.host_id
      and (
        (old.starts_at is not distinct from new.starts_at
          and old.ends_at is not distinct from new.ends_at)
        or not public.activity_schedule_conflicts(
          participant.user_id,new.starts_at,new.ends_at,new.id
        )
      )
  loop
    insert into public.activity_update_notification_outbox(
      user_id,activity_id,activity_title,schedule_changed
    ) values(recipient.user_id,new.id,new.title,
      old.starts_at is distinct from new.starts_at
        or old.ends_at is distinct from new.ends_at)
      returning id into notification_id;
    if function_url is null or webhook_secret is null then
      raise warning 'Activity update push endpoint or webhook secret is not configured.';
      continue;
    end if;
    begin
      perform net.http_post(url:=function_url,
        headers:=jsonb_build_object('Content-Type','application/json',
          'x-waitlist-push-secret',webhook_secret),
        body:=jsonb_build_object('event_id',notification_id,'event_type','activity_updated'),
        timeout_milliseconds:=5000);
    exception when others then
      raise warning 'Could not queue activity update notification: %',sqlerrm;
    end;
  end loop;
  return new;
end;
$$;

drop trigger if exists activity_update_push on public.activities;
create trigger activity_update_push
after update of title, description, starts_at, location_name, location_address,
  latitude, longitude, max_participants, is_public, setting, photo_url
on public.activities
for each row
execute function public.enqueue_activity_update_notifications();
