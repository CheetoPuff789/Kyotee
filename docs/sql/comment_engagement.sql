-- Enable required extension for UUIDs (if not already enabled)
create extension if not exists pgcrypto;

-- Ensure post_comments has RLS and owner policies for update/delete
alter table if exists public.post_comments enable row level security;

do $$ begin
  -- SELECT for authenticated
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='post_comments' and policyname='post_comments_select_auth') then
    create policy post_comments_select_auth on public.post_comments
      for select to authenticated using (true);
  end if;

  -- INSERT by owner
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='post_comments' and policyname='post_comments_insert_owner') then
    create policy post_comments_insert_owner on public.post_comments
      for insert to authenticated with check (auth.uid() = user_id);
  end if;

  -- UPDATE by owner
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='post_comments' and policyname='post_comments_update_owner') then
    create policy post_comments_update_owner on public.post_comments
      for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;

  -- DELETE by owner
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='post_comments' and policyname='post_comments_delete_owner') then
    create policy post_comments_delete_owner on public.post_comments
      for delete to authenticated using (auth.uid() = user_id);
  end if;
end $$;

-- Comment likes table
create table if not exists public.comment_likes (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid not null references public.post_comments(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(comment_id, user_id)
);

alter table public.comment_likes enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='comment_likes' and policyname='comment_likes_select_auth') then
    create policy comment_likes_select_auth on public.comment_likes
      for select to authenticated using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='comment_likes' and policyname='comment_likes_insert_owner') then
    create policy comment_likes_insert_owner on public.comment_likes
      for insert to authenticated with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='comment_likes' and policyname='comment_likes_delete_owner') then
    create policy comment_likes_delete_owner on public.comment_likes
      for delete to authenticated using (auth.uid() = user_id);
  end if;
end $$;

-- Comment replies table
create table if not exists public.comment_replies (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid not null references public.post_comments(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_comment_replies_comment_id on public.comment_replies(comment_id);

alter table public.comment_replies enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='comment_replies' and policyname='comment_replies_select_auth') then
    create policy comment_replies_select_auth on public.comment_replies
      for select to authenticated using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='comment_replies' and policyname='comment_replies_insert_owner') then
    create policy comment_replies_insert_owner on public.comment_replies
      for insert to authenticated with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='comment_replies' and policyname='comment_replies_update_owner') then
    create policy comment_replies_update_owner on public.comment_replies
      for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='comment_replies' and policyname='comment_replies_delete_owner') then
    create policy comment_replies_delete_owner on public.comment_replies
      for delete to authenticated using (auth.uid() = user_id);
  end if;
end $$;

