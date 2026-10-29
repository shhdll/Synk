-- Store each device's app language so activity-full push text can be localized.
alter table public.push_device_tokens
  add column if not exists language text not null default 'en'
    check (language in ('en', 'ar'));
