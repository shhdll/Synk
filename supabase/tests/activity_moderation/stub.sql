-- Stand-ins for what Supabase and earlier migrations provide, so the
-- activity moderation migration can be tested on a plain local Postgres.
-- Not a copy of the real schema: only the parts these tests touch.

create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;

create schema auth;
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
grant usage on schema auth to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;
grant usage on schema public to anon, authenticated, service_role;
-- Supabase gives these roles table access by default; RLS and revokes limit it.
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;

create schema private;
grant usage on schema private to authenticated, service_role;

create table public.users (
  id uuid primary key,
  full_name text
);

-- From 20261107100000_admin_dashboard.sql.
create table private.user_suspensions (user_id uuid primary key references public.users (id));
create function private.is_suspended(target_user_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from private.user_suspensions where user_id = target_user_id);
$$;

-- The activity columns the app writes (the table itself was made in the
-- dashboard), plus a count column a trigger keeps, like joined counts.
create table public.activities (
  id uuid primary key default gen_random_uuid(),
  host_id uuid references public.users (id),
  title text not null,
  description text,
  starts_at timestamptz not null,
  ends_at timestamptz,
  location_name text,
  location_address text,
  latitude double precision,
  longitude double precision,
  max_participants integer not null default 4,
  is_public boolean not null default true,
  setting text check (setting in ('indoor', 'outdoor')),
  category_emoji text,
  category_label text,
  photo_url text,
  activity_code text,
  participants_note integer not null default 0,
  created_at timestamptz not null default now()
);
alter table public.activities enable row level security;
create policy "Anyone signed in can read" on public.activities for select to authenticated using (true);
create policy "Hosts write their own" on public.activities for insert to authenticated
  with check (host_id = auth.uid());
create policy "Hosts update their own" on public.activities for update to authenticated
  using (host_id = auth.uid());
create policy "Hosts delete their own" on public.activities for delete to authenticated
  using (host_id = auth.uid());

-- The existing checks, raising the same messages as the real triggers.
create function public.stub_activity_checks() returns trigger language plpgsql as $$
begin
  if new.ends_at <= new.starts_at then
    raise exception 'The activity end time must be after its start time.';
  end if;
  if new.starts_at > now() + interval '3 months' then
    raise exception 'Activities can only be scheduled up to 3 months in advance.';
  end if;
  if new.title = 'Schedule clash' then
    raise exception 'You already have an activity scheduled during this time. Please choose a different date or time.';
  end if;
  if tg_op = 'UPDATE' and new.max_participants < 3 then
    raise exception 'Capacity cannot be lower than the current number of participants (3 confirmed).';
  end if;
  return new;
end;
$$;
create trigger activities_validate_schedule_capacity
  before insert or update on public.activities
  for each row execute function public.stub_activity_checks();

-- Counts trigger runs, to prove retries don't run them again.
create table public.trigger_runs (op text, activity_id uuid, at timestamptz default now());
create function public.stub_count_runs() returns trigger language plpgsql security definer as $$
begin
  insert into public.trigger_runs (op, activity_id) values (tg_op, new.id);
  return null;
end;
$$;
create trigger activities_count_runs
  after insert or update on public.activities
  for each row execute function public.stub_count_runs();

-- An internal security definer function, like host transfer.
create function public.stub_transfer_host(target uuid, new_host uuid)
returns void language sql security definer set search_path = '' as $$
  update public.activities set host_id = new_host where id = target;
$$;
grant execute on function public.stub_transfer_host(uuid, uuid) to authenticated;

-- Storage, as far as the lock-down touches it.
create schema storage;
create table storage.buckets (
  id text primary key,
  allowed_mime_types text[],
  file_size_limit bigint
);
insert into storage.buckets (id) values ('activity-photos');
create table storage.objects (
  bucket_id text,
  name text,
  owner uuid
);
alter table storage.objects enable row level security;
create function storage.foldername(name text) returns text[] language sql immutable as $$
  select string_to_array(name, '/');
$$;
create function storage.filename(name text) returns text language sql immutable as $$
  select (string_to_array(name, '/'))[array_length(string_to_array(name, '/'), 1)];
$$;
grant usage on schema storage to authenticated;
grant all on storage.objects to authenticated;
-- As they are after 20261014100400_activity_photo_host_policies.sql.
create policy "activity-photos: owner insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'activity-photos');
create policy "activity-photos: owner update" on storage.objects for update to authenticated
  using (bucket_id = 'activity-photos') with check (bucket_id = 'activity-photos');
create policy "activity-photos: owner delete" on storage.objects for delete to authenticated
  using (bucket_id = 'activity-photos');
create policy "activity-photos: public read" on storage.objects for select
  using (bucket_id = 'activity-photos');

insert into public.users (id, full_name) values
  ('00000000-0000-0000-0000-00000000000a', 'Amal'),
  ('00000000-0000-0000-0000-00000000000b', 'Sara'),
  ('00000000-0000-0000-0000-00000000000c', 'Suspended');
insert into private.user_suspensions (user_id) values ('00000000-0000-0000-0000-00000000000c');
