-- Supabase setup for Kyotee: tables, RLS, and helpers
-- Run this in the Supabase SQL Editor (SQL tab) as the service role.

-- UUID helper
create extension if not exists pgcrypto;

-- profiles: 1 row per user (auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  email text,
  avatar_url text
);
alter table public.profiles enable row level security;

create policy if not exists "profiles_select_all" on public.profiles for select using (true);
create policy if not exists "profiles_insert_self" on public.profiles for insert with check (auth.uid() = id);
create policy if not exists "profiles_update_self" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

-- Auto-create profile when a new auth user is created
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, username, email)
  values (new.id, split_part(new.email, '@', 1), new.email)
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- posts
create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  content text not null default '',
  image_url text,
  created_at timestamptz not null default now()
);
alter table public.posts enable row level security;

create policy if not exists "posts_select_all" on public.posts for select using (true);
create policy if not exists "posts_insert_self" on public.posts for insert with check (auth.uid() = user_id);
create policy if not exists "posts_update_self" on public.posts for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy if not exists "posts_delete_self" on public.posts for delete using (auth.uid() = user_id);

-- friends
create table if not exists public.friends (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  accepter_id uuid not null references public.profiles(id) on delete cascade,
  status text not null check (status in ('pending','accepted')),
  created_at timestamptz not null default now(),
  constraint friends_no_self check (requester_id <> accepter_id)
);
-- prevent duplicate friendship regardless of order
create unique index if not exists uniq_friend_pair
  on public.friends (least(requester_id, accepter_id), greatest(requester_id, accepter_id));

-- Ensure predictable FK constraint names for PostgREST embedding
do $$ begin
  if not exists (
    select 1 from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    where c.conname = 'friends_requester_id_fkey' and t.relname = 'friends'
  ) then
    alter table public.friends
      add constraint friends_requester_id_fkey
      foreign key (requester_id) references public.profiles(id) on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    where c.conname = 'friends_accepter_id_fkey' and t.relname = 'friends'
  ) then
    alter table public.friends
      add constraint friends_accepter_id_fkey
      foreign key (accepter_id) references public.profiles(id) on delete cascade;
  end if;
end $$;

alter table public.friends enable row level security;

create policy if not exists "friends_read_involved" on public.friends
for select using (auth.uid() = requester_id or auth.uid() = accepter_id);

create policy if not exists "friends_insert_requester" on public.friends
for insert with check (auth.uid() = requester_id and requester_id <> accepter_id);

create policy if not exists "friends_update_accepter" on public.friends
for update using (auth.uid() = accepter_id) with check (auth.uid() = accepter_id);

create policy if not exists "friends_delete_involved" on public.friends
for delete using (auth.uid() = requester_id or auth.uid() = accepter_id);

-- messages
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  content text not null,
  read boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.messages enable row level security;

create policy if not exists "messages_read_involved" on public.messages
for select using (auth.uid() = sender_id or auth.uid() = receiver_id);

create policy if not exists "messages_insert_sender" on public.messages
for insert with check (auth.uid() = sender_id);

create policy if not exists "messages_update_receiver" on public.messages
for update using (auth.uid() = receiver_id) with check (auth.uid() = receiver_id);

-- Storage buckets (create via Dashboard -> Storage):
-- Ensure buckets exist (equivalent to creating in dashboard)
insert into storage.buckets (id, name, public)
values ('post_images', 'post_images', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('profile_pictures', 'profile_pictures', true)
on conflict (id) do nothing;

-- Storage policies: public read; authenticated users may write
create policy if not exists "Public read post_images" on storage.objects
for select using (bucket_id = 'post_images');

create policy if not exists "Public read profile_pictures" on storage.objects
for select using (bucket_id = 'profile_pictures');

create policy if not exists "Auth write post_images" on storage.objects
for insert to authenticated with check (bucket_id = 'post_images');

create policy if not exists "Auth write profile_pictures" on storage.objects
for insert to authenticated with check (bucket_id = 'profile_pictures');

create policy if not exists "Auth update post_images" on storage.objects
for update to authenticated using (bucket_id = 'post_images') with check (bucket_id = 'post_images');

create policy if not exists "Auth update profile_pictures" on storage.objects
for update to authenticated using (bucket_id = 'profile_pictures') with check (bucket_id = 'profile_pictures');

create policy if not exists "Auth delete post_images" on storage.objects
for delete to authenticated using (bucket_id = 'post_images');

create policy if not exists "Auth delete profile_pictures" on storage.objects
for delete to authenticated using (bucket_id = 'profile_pictures');

-- Feed: reactions (likes/dislikes), comments, and views

-- post_reactions: one reaction per (post_id, user_id)
create table if not exists public.post_reactions (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reaction text not null check (reaction in ('like','dislike')),
  created_at timestamptz not null default now(),
  unique (post_id, user_id)
);
alter table public.post_reactions enable row level security;

-- RLS: any authenticated user may read; only the owner may write
create policy if not exists "post_reactions_select_all_auth" on public.post_reactions
for select to authenticated using (true);
create policy if not exists "post_reactions_insert_self" on public.post_reactions
for insert to authenticated with check (auth.uid() = user_id);
create policy if not exists "post_reactions_update_self" on public.post_reactions
for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy if not exists "post_reactions_delete_self" on public.post_reactions
for delete to authenticated using (auth.uid() = user_id);

-- post_comments: free‑form comments per post
create table if not exists public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);
alter table public.post_comments enable row level security;

-- RLS: any authenticated user may read; only the owner may write
create policy if not exists "post_comments_select_all_auth" on public.post_comments
for select to authenticated using (true);
create policy if not exists "post_comments_insert_self" on public.post_comments
for insert to authenticated with check (auth.uid() = user_id);
create policy if not exists "post_comments_update_self" on public.post_comments
for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy if not exists "post_comments_delete_self" on public.post_comments
for delete to authenticated using (auth.uid() = user_id);

-- post_views: track which user has viewed which post (idempotent)
create table if not exists public.post_views (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (post_id, user_id)
);
alter table public.post_views enable row level security;

-- RLS: users can only read and write their own view rows
create policy if not exists "post_views_select_self" on public.post_views
for select to authenticated using (auth.uid() = user_id);
create policy if not exists "post_views_insert_self" on public.post_views
for insert to authenticated with check (auth.uid() = user_id);
create policy if not exists "post_views_update_self" on public.post_views
for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy if not exists "post_views_delete_self" on public.post_views
for delete to authenticated using (auth.uid() = user_id);

-- Realtime: ensure these tables are included in the supabase_realtime publication
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'posts'
    ) then
      alter publication supabase_realtime add table public.posts;
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'post_reactions'
    ) then
      alter publication supabase_realtime add table public.post_reactions;
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'post_comments'
    ) then
      alter publication supabase_realtime add table public.post_comments;
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'post_views'
    ) then
      alter publication supabase_realtime add table public.post_views;
    end if;
  end if;
end $$;
