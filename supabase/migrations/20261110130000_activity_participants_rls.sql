-- RLS was turned on for activity_participants outside the migrations.
-- Turn it on here too so a fresh setup is protected.
alter table public.activity_participants
enable row level security;
