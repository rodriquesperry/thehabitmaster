-- 001_schema.sql
-- Atomic Habits + Pomodoro Starter
-- Enable needed extensions
create extension if not exists pgcrypto;
create extension if not exists "uuid-ossp";

-- Profiles (mirror of auth.users via FK)
create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  tz text default 'America/Chicago',
  created_at timestamptz default now()
);

-- Habits
create table if not exists public.habits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  identity_text text,
  cue text,
  attraction text,
  friction_reducers text,
  reward text,
  target_per_week int default 5 check (target_per_week between 1 and 14),
  difficulty int default 2 check (difficulty between 1 and 5),
  is_archived boolean default false,
  created_at timestamptz default now()
);

-- Weekly schedule blocks
create table if not exists public.schedule_blocks (
  id uuid primary key default gen_random_uuid(),
  habit_id uuid not null references public.habits(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  dow int not null check (dow between 0 and 6),      -- 0=Sun
  start_min int not null check (start_min between 0 and 1439),
  duration_min int not null default 25 check (duration_min between 5 and 300),
  created_at timestamptz default now()
);

-- Sessions (one or more pomodoros)
create table if not exists public.sessions (
  id uuid primary key default gen_random_uuid(),
  habit_id uuid not null references public.habits(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  started_at timestamptz default now(),
  planned_duration_min int,
  actual_duration_min int,
  completed boolean default false,
  notes text
);

-- Pomodoros (focus/break segments inside a session)
create table if not exists public.pomodoros (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('focus','break')),
  duration_sec int not null check (duration_sec between 60 and 7200),
  started_at timestamptz default now()
);

-- Accountability (optional partner + stakes)
create table if not exists public.accountability (
  id uuid primary key default gen_random_uuid(),
  habit_id uuid not null references public.habits(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  partner_email text,
  stake_cents int default 0 check (stake_cents >= 0),
  created_at timestamptz default now()
);

-- -------------------
-- RLS
-- -------------------
alter table public.profiles enable row level security;
alter table public.habits enable row level security;
alter table public.schedule_blocks enable row level security;
alter table public.sessions enable row level security;
alter table public.pomodoros enable row level security;
alter table public.accountability enable row level security;

-- Profiles policies
create policy if not exists "profiles_select_own"
  on public.profiles for select
  using (user_id = auth.uid());

create policy if not exists "profiles_upsert_own"
  on public.profiles for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Habits policies
create policy if not exists "habits_select_own"
  on public.habits for select
  using (user_id = auth.uid());

create policy if not exists "habits_all_own"
  on public.habits for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- schedule_blocks policies
create policy if not exists "schedule_blocks_select_own"
  on public.schedule_blocks for select
  using (user_id = auth.uid());

create policy if not exists "schedule_blocks_all_own"
  on public.schedule_blocks for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- sessions policies
create policy if not exists "sessions_select_own"
  on public.sessions for select
  using (user_id = auth.uid());

create policy if not exists "sessions_all_own"
  on public.sessions for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- pomodoros policies
create policy if not exists "pomodoros_select_own"
  on public.pomodoros for select
  using (user_id = auth.uid());

create policy if not exists "pomodoros_all_own"
  on public.pomodoros for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- accountability policies
create policy if not exists "accountability_select_own"
  on public.accountability for select
  using (user_id = auth.uid());

create policy if not exists "accountability_all_own"
  on public.accountability for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Convenience views
create or replace view public.v_habit_stats as
select
  h.id as habit_id,
  h.title,
  h.user_id,
  count(s.id) filter (where s.completed) as completed_sessions,
  count(s.id) as total_sessions,
  coalesce(round(100.0 * count(s.id) filter (where s.completed) / nullif(count(s.id),0)), 0) as completion_rate_pct
from public.habits h
left join public.sessions s on s.habit_id = h.id and s.user_id = h.user_id
group by 1,2,3;

-- -------------------
-- Seed helper (call with your actual user_id)
-- -------------------
create or replace function public.seed_habits(p_user_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  -- Create profile if not exists
  insert into public.profiles (user_id, display_name)
  values (p_user_id, 'You')
  on conflict (user_id) do nothing;

  -- Insert five sample habits
  insert into public.habits (user_id, title, identity_text, cue, attraction, friction_reducers, reward, target_per_week, difficulty)
  values
    (p_user_id, 'Morning Stretch', 'I am someone who cares for my body.', 'After brushing teeth, unroll mat.', 'Play favorite calm playlist.', 'Mat laid out at night.', 'Check off streak + 30s haptic confetti.', 5, 1),
    (p_user_id, 'Deep Work Block', 'I am the kind of engineer who ships.', '9:00 AM at desk; noise-cancelling on.', 'Coffee ritual + focus playlist.', 'One-tab rule; website blocker.', 'Mark a Win in journal.', 5, 3),
    (p_user_id, 'Read 10 Pages', 'I am a learner who grows daily.', 'Book beside pillow.', 'Tea while reading.', 'Remove phone from bedroom.', 'Add to reading streak.', 7, 2),
    (p_user_id, 'Daily Walk', 'I am active and energized.', 'After lunch, shoes by door.', 'Podcast only during walk.', 'Shoes visible; route pre-picked.', 'Fresh-air badge.', 7, 1),
    (p_user_id, 'Code Practice', 'I am a craftsperson who improves.', '6:30 PM laptop open.', 'Lo-fi beats.', 'Open kata before start.', 'Green check + XP.', 4, 3);

  -- Sample schedule blocks (Mon-Fri deep work; daily short habits)
  insert into public.schedule_blocks (habit_id, user_id, dow, start_min, duration_min)
  select id, user_id, dow, start_min, duration_min from (
    values
      -- Morning Stretch 7:00 (10m) every day
      ((select id from public.habits where user_id=p_user_id and title='Morning Stretch'), 0, 420, 10),
      ((select id from public.habits where user_id=p_user_id and title='Morning Stretch'), 1, 420, 10),
      ((select id from public.habits where user_id=p_user_id and title='Morning Stretch'), 2, 420, 10),
      ((select id from public.habits where user_id=p_user_id and title='Morning Stretch'), 3, 420, 10),
      ((select id from public.habits where user_id=p_user_id and title='Morning Stretch'), 4, 420, 10),
      ((select id from public.habits where user_id=p_user_id and title='Morning Stretch'), 5, 480, 10),
      ((select id from public.habits where user_id=p_user_id and title='Morning Stretch'), 6, 480, 10),

      -- Deep Work 9:00 (50m) Mon-Fri
      ((select id from public.habits where user_id=p_user_id and title='Deep Work Block'), 1, 540, 50),
      ((select id from public.habits where user_id=p_user_id and title='Deep Work Block'), 2, 540, 50),
      ((select id from public.habits where user_id=p_user_id and title='Deep Work Block'), 3, 540, 50),
      ((select id from public.habits where user_id=p_user_id and title='Deep Work Block'), 4, 540, 50),
      ((select id from public.habits where user_id=p_user_id and title='Deep Work Block'), 5, 540, 50),

      -- Read 10 Pages 20:30 (20m) daily
      ((select id from public.habits where user_id=p_user_id and title='Read 10 Pages'), 0, 1230, 20),
      ((select id from public.habits where user_id=p_user_id and title='Read 10 Pages'), 1, 1230, 20),
      ((select id from public.habits where user_id=p_user_id and title='Read 10 Pages'), 2, 1230, 20),
      ((select id from public.habits where user_id=p_user_id and title='Read 10 Pages'), 3, 1230, 20),
      ((select id from public.habits where user_id=p_user_id and title='Read 10 Pages'), 4, 1230, 20),
      ((select id from public.habits where user_id=p_user_id and title='Read 10 Pages'), 5, 1230, 20),
      ((select id from public.habits where user_id=p_user_id and title='Read 10 Pages'), 6, 1230, 20),

      -- Daily Walk 13:00 (25m) daily
      ((select id from public.habits where user_id=p_user_id and title='Daily Walk'), 0, 780, 25),
      ((select id from public.habits where user_id=p_user_id and title='Daily Walk'), 1, 780, 25),
      ((select id from public.habits where user_id=p_user_id and title='Daily Walk'), 2, 780, 25),
      ((select id from public.habits where user_id=p_user_id and title='Daily Walk'), 3, 780, 25),
      ((select id from public.habits where user_id=p_user_id and title='Daily Walk'), 4, 780, 25),
      ((select id from public.habits where user_id=p_user_id and title='Daily Walk'), 5, 780, 25),
      ((select id from public.habits where user_id=p_user_id and title='Daily Walk'), 6, 780, 25),

      -- Code Practice 18:30 (30m) Mon, Wed, Fri, Sat
      ((select id from public.habits where user_id=p_user_id and title='Code Practice'), 1, 1110, 30),
      ((select id from public.habits where user_id=p_user_id and title='Code Practice'), 3, 1110, 30),
      ((select id from public.habits where user_id=p_user_id and title='Code Practice'), 5, 1110, 30),
      ((select id from public.habits where user_id=p_user_id and title='Code Practice'), 6, 1110, 30)
  ) as t(habit_id, dow, start_min, duration_min)
  cross join (select p_user_id as user_id) u;
end;
$$;
