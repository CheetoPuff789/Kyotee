-- Run these statements in the Supabase SQL editor
-- Sync profiles.email on user add/delete and keep emails unique

-- 1) Ensure profiles has a unique email
alter table if exists public.profiles
  add constraint if not exists profiles_email_unique unique (email);

-- 2) Create function to insert a profile row on auth.user creation
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public, extensions
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;

-- 3) Trigger on auth.users insert
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 4) Create function to remove profile row on auth.user deletion
create or replace function public.handle_deleted_user()
returns trigger
language plpgsql
security definer set search_path = public, extensions
as $$
begin
  delete from public.profiles where id = old.id;
  return old;
end;
$$;

-- 5) Trigger on auth.users delete
drop trigger if exists on_auth_user_deleted on auth.users;
create trigger on_auth_user_deleted
  after delete on auth.users
  for each row execute procedure public.handle_deleted_user();

-- Optional: if you also want to cascade delete user content, add similar triggers or
-- use foreign keys with on delete cascade where appropriate.

