Admin: Ban/Unban Users

Overview

- A dev account (set in `lib/main.dart` as `devUserId`) can search users and ban/unban them from the Admin Tools screen.
- Banned users are prevented in the UI from posting, commenting, and messaging. The backend should enforce this with RLS.

Schema changes

- Add a `banned boolean not null default false` and optional `banned_until timestamptz` column on `profiles`.

alter table public.profiles
  add column if not exists banned boolean not null default false,
  add column if not exists banned_until timestamptz;

- Add a banned email denylist to prevent re-registering with banned emails, even if account is deleted later.

create table if not exists public.banned_emails (
  email text primary key,
  banned_until timestamptz,
  created_at timestamptz not null default now()
);

RLS policies (samples)

-- Allow dev to toggle banned flag on profiles
create policy if not exists profiles_update_dev on public.profiles
for update using (auth.uid() = 'a41f959f-fbfe-41ae-8daf-40beaa876635'::uuid);

-- Normal self-update policy (if you already have one, keep it)
create policy if not exists profiles_update_self on public.profiles
for update using (auth.uid() = id);

-- Block banned users from creating posts
create policy if not exists posts_insert_not_banned on public.posts
for insert to authenticated
with check (
  (select not coalesce(banned, false) from public.profiles p where p.id = auth.uid())
);

-- Block banned users from commenting
create policy if not exists comments_insert_not_banned on public.post_comments
for insert to authenticated
with check (
  (select not coalesce(banned, false) from public.profiles p where p.id = auth.uid())
);

-- Block banned users from sending messages
create policy if not exists messages_insert_not_banned on public.messages
for insert to authenticated
with check (
  (select not coalesce(banned, false) from public.profiles p where p.id = auth.uid())
);

-- Optional: lock down banned_emails so only dev can modify
alter table public.banned_emails enable row level security;
create policy if not exists banned_emails_dev_all on public.banned_emails
for all using (auth.uid() = 'YOUR_DEV_UUID'::uuid) with check (auth.uid() = 'YOUR_DEV_UUID'::uuid);

Feed filtering

- Client already excludes posts from banned authors by reading `profiles.banned` in joins.

Realtime

- No special changes needed. Consider adding a policy to allow dev to read all profiles for search (or add a dedicated search RPC that enforces dev auth).

Security notes

- Replace YOUR_DEV_UUID in policies with the real dev UUID, and keep it in sync with `devUserId` in `lib/main.dart`.
- For stricter control, put a `app_metadata.dev` flag in your auth JWT and write policies using `auth.jwt() -> 'app_metadata' ->> 'dev' = 'true'` instead of a raw UUID.

Auto-unban (scheduled)

- If you use temporary bans, schedule a daily job via pg_cron to auto-unban users whose `banned_until` has passed, and to clear expired banned emails:

-- enable extension (if not already)
create extension if not exists pg_cron;

-- auto-unban profiles
select cron.schedule('0 3 * * *', $$
  update public.profiles
  set banned = false, banned_until = null
  where banned = true and banned_until is not null and banned_until <= now();
$$);

-- clear expired banned emails
select cron.schedule('5 3 * * *', $$
  delete from public.banned_emails
  where banned_until is not null and banned_until <= now();
$$);

Alternatively, use an Edge Function + Scheduled Triggers if you prefer Supabase Functions over pg_cron.
