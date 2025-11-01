-- Adds a phone column to the profiles table if it doesn't exist
alter table public.profiles
  add column if not exists phone text;

-- Optional: backfill a known dev account phone (replace UUID if needed)
-- update public.profiles set phone = '925-496-6211' where id = 'a41f959f-fbfe-41ae-8daf-40beaa876635';

-- If you use RLS, ensure your update policy already allows users to update their own row.
-- Example policy (only add if you don't already have one covering updates):
-- create policy "update_own_profile"
--   on public.profiles for update
--   using (auth.uid() = id)
--   with check (auth.uid() = id);
