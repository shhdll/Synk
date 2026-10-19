-- The create form treats an empty description as optional.
alter table public.activities
alter column description drop not null;
