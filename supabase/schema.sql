-- Meeting Action Tracker — database schema
-- Run against a Supabase project (SQL Editor, or `supabase db execute`).
-- Safe to re-run: every statement is idempotent.

-- ============================================================
-- Actions
-- ============================================================

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

-- ============================================================
-- Profiles — the app's view of who a user is
-- ============================================================
-- auth.users holds the credentials; it is managed by Supabase and the
-- app never reads it directly. profiles carries the username and
-- display name, and is what the board joins against.

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9_]{2,32}$'),
  display_name text not null,
  created_at timestamptz not null default now()
);

-- Every new auth user automatically gets a profile, built from the
-- username / display_name carried in raw_user_meta_data.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'username', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data ->> 'display_name', initcap(split_part(new.email, '@', 1)))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- Row-level security
-- ============================================================
-- Nothing is readable without a session. Any signed-in user can read
-- and edit every action — this is a shared team board, not per-user
-- data — but anonymous callers holding only the publishable key get
-- nothing at all.

alter table public.meeting_actions enable row level security;
alter table public.profiles enable row level security;

drop policy if exists "anon read actions" on public.meeting_actions;
drop policy if exists "anon insert actions" on public.meeting_actions;
drop policy if exists "anon update actions" on public.meeting_actions;
drop policy if exists "anon delete actions" on public.meeting_actions;
drop policy if exists "signed in read actions" on public.meeting_actions;
drop policy if exists "signed in insert actions" on public.meeting_actions;
drop policy if exists "signed in update actions" on public.meeting_actions;
drop policy if exists "signed in delete actions" on public.meeting_actions;

create policy "signed in read actions" on public.meeting_actions
  for select to authenticated using (true);
create policy "signed in insert actions" on public.meeting_actions
  for insert to authenticated with check (true);
create policy "signed in update actions" on public.meeting_actions
  for update to authenticated using (true) with check (true);
create policy "signed in delete actions" on public.meeting_actions
  for delete to authenticated using (true);

drop policy if exists "profiles readable by signed in users" on public.profiles;
drop policy if exists "users update own profile" on public.profiles;

create policy "profiles readable by signed in users" on public.profiles
  for select to authenticated using (true);
create policy "users update own profile" on public.profiles
  for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);
