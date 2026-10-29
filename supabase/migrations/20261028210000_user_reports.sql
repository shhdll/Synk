-- Reports users file against other users, for the Synk team to review.
--
-- Users can only create reports, through report_user(). Nobody can read them
-- through the API yet; the team reviews them in Supabase Studio until the
-- admin dashboard adds its own read and review access.

begin;

create table if not exists public.user_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.users (id) on delete cascade,
  reported_user_id uuid not null references public.users (id) on delete cascade,
  reason text not null
    check (reason in ('harassment', 'spam', 'fake_profile', 'inappropriate_content', 'other')),
  details text check (details is null or char_length(details) <= 1000),
  -- "Something else" means nothing without an explanation.
  constraint user_reports_other_needs_details
    check (reason <> 'other' or details is not null),
  status text not null default 'open'
    check (status in ('open', 'reviewing', 'resolved', 'dismissed')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.users (id) on delete set null,
  constraint user_reports_not_self check (reporter_id <> reported_user_id)
);

-- One open report per reporter and user, so the same person can't be
-- reported over and over before the team looks at it.
create unique index if not exists user_reports_one_open_per_pair
  on public.user_reports (reporter_id, reported_user_id)
  where status in ('open', 'reviewing');

create index if not exists user_reports_queue_idx
  on public.user_reports (status, created_at desc);

create index if not exists user_reports_reported_user_idx
  on public.user_reports (reported_user_id);

alter table public.user_reports enable row level security;
revoke all on public.user_reports from public, anon, authenticated;

create or replace function public.report_user(
  target_user_id uuid,
  report_reason text,
  report_details text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.require_signed_in();
  cleaned_details text := nullif(btrim(coalesce(report_details, '')), '');
begin
  if target_user_id = me then
    return jsonb_build_object('result', 'self');
  end if;

  if not exists (select 1 from public.users where id = target_user_id) then
    return jsonb_build_object('result', 'not_found');
  end if;

  if report_reason is null or report_reason not in
      ('harassment', 'spam', 'fake_profile', 'inappropriate_content', 'other') then
    return jsonb_build_object('result', 'invalid_reason');
  end if;

  if report_reason = 'other' and cleaned_details is null then
    return jsonb_build_object('result', 'details_required');
  end if;

  if cleaned_details is not null and char_length(cleaned_details) > 1000 then
    return jsonb_build_object('result', 'details_too_long');
  end if;

  insert into public.user_reports (reporter_id, reported_user_id, reason, details)
  values (me, target_user_id, report_reason, cleaned_details)
  on conflict (reporter_id, reported_user_id)
    where status in ('open', 'reviewing')
    do nothing;

  if not found then
    return jsonb_build_object('result', 'already_reported');
  end if;

  return jsonb_build_object('result', 'reported');
end;
$$;

revoke all on function public.report_user(uuid, text, text) from public, anon;
grant execute on function public.report_user(uuid, text, text) to authenticated;

commit;
