-- 002_seed.sql
-- Call this AFTER you have a user in auth.users.
-- Replace <YOUR_USER_ID> with the UUID of your signed-up user,
-- or run: select seed_habits('<YOUR_USER_ID>');
select public.seed_habits('<YOUR_USER_ID>');
