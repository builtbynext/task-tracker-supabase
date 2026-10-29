-- Meeting Action Tracker — database schema
-- Run against a Supabase project (SQL Editor, or `supabase db execute`).
-- Safe to re-run: every statement is idempotent.

create table if not exists public.meeting_actions (
  id uuid primary key default gen_random_uuid(),
  title text not null check (length(btrim(title)) > 0),
  owner_name text not null check (length(btrim(owner_name)) > 0),
  due_on date,
  meeting text,
  done boolean not null default false,
  done_on date,
  agreed_on date not null default current_date,
  is_sample boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists meeting_actions_owner_idx on public.meeting_actions (owner_name);
create index if not exists meeting_actions_open_due_idx on public.meeting_actions (done, due_on);

-- Keep updated_at honest on every write.
create or replace function public.touch_meeting_actions()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists meeting_actions_touch on public.meeting_actions;
create trigger meeting_actions_touch
  before update on public.meeting_actions
  for each row execute function public.touch_meeting_actions();

-- Row-level security.
--
-- WARNING: these policies give anyone holding the publishable key full
-- read/write/delete access to every row. That is deliberate for a small
-- trusted team on a private URL. If this board goes anywhere public,
-- replace the `to anon` grants below with policies scoped to
-- `authenticated` and wire up Supabase Auth in index.html.
alter table public.meeting_actions enable row level security;

drop policy if exists "anon read actions" on public.meeting_actions;
drop policy if exists "anon insert actions" on public.meeting_actions;
drop policy if exists "anon update actions" on public.meeting_actions;
drop policy if exists "anon delete actions" on public.meeting_actions;

create policy "anon read actions" on public.meeting_actions
  for select to anon, authenticated using (true);
create policy "anon insert actions" on public.meeting_actions
  for insert to anon, authenticated with check (true);
create policy "anon update actions" on public.meeting_actions
  for update to anon, authenticated using (true) with check (true);
create policy "anon delete actions" on public.meeting_actions
  for delete to anon, authenticated using (true);

-- Realtime: `replica identity full` so DELETE events carry the old row.
alter table public.meeting_actions replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'meeting_actions'
  ) then
    alter publication supabase_realtime add table public.meeting_actions;
  end if;
end
$$;
