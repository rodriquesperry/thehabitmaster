# Atomic Habits + Pomodoro — Starter

This starter pairs **Supabase** (Auth + Postgres + RLS) with **Next.js (App Router)** and a basic **Pomodoro** timer.
It includes SQL migrations, a seed function for 5 sample habits, and lightweight pages for auth, timer, and stats.

## 1) Create Supabase project
- Get your `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY`.
- In Supabase SQL editor, run `supabase/sql/001_schema.sql`.
- After you sign up the first user in the app, get that user’s UUID from **Auth → Users**.
- Run `supabase/sql/002_seed.sql` after replacing `<YOUR_USER_ID>` with that UUID **OR** execute:
  ```sql
  select public.seed_habits('<YOUR_USER_ID>');
  ```

## 2) Configure env
Copy `.env.example` to `.env.local` and fill in keys.

## 3) Install & run
```bash
pnpm i   # or npm i / yarn
pnpm dev
```

Open http://localhost:3000

## 4) Notes
- RLS policies restrict all rows to `auth.uid()` (the logged-in user).
- The `Stats` page reads from a convenience view `v_habit_stats`.
- The simple session flow:
  - Pick a habit → **Start Session** inserts a row in `sessions` (planned 25m).
  - **Complete Session** marks it completed and sets `actual_duration_min`=25 (adjust as needed).
- Extend by adding notifications, schedule visualization, and mobile via Expo/React Native.
# thehabitmaster
