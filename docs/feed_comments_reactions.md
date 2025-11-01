Feed: Likes/Dislikes and Comments

Database tables expected in Supabase:

- Table `post_reactions`
  - id: uuid (default gen_random_uuid())
  - post_id: uuid references posts(id) on delete cascade
  - user_id: uuid references auth.users(id) on delete cascade
  - reaction: text check (reaction in ('like','dislike'))
  - created_at: timestamptz default now()
  - unique (post_id, user_id)

- Table `post_comments`
  - id: uuid (default gen_random_uuid())
  - post_id: uuid references posts(id) on delete cascade
  - user_id: uuid references auth.users(id) on delete cascade
  - content: text not null
  - created_at: timestamptz default now()

- Table `post_views`
  - id: uuid (default gen_random_uuid())
  - post_id: uuid references posts(id) on delete cascade
  - user_id: uuid references auth.users(id) on delete cascade
  - created_at: timestamptz default now()
  - unique (post_id, user_id)

Suggested RLS policies (adjust to your auth model):

- Enable RLS on both tables
- post_reactions
  - select: authenticated can read all
  - insert: user_id = auth.uid()
  - update: user_id = auth.uid()
  - delete: user_id = auth.uid()

- post_comments
  - select: authenticated can read all
  - insert: user_id = auth.uid()
  - update/delete (optional): user_id = auth.uid()

Profile join support:

- Ensure a `profiles` table exists with columns: id (uuid pk, equals auth.users.id), username text, avatar_url text.
- Create a foreign key from post_comments.user_id -> profiles.id (optional; code uses a select with `profiles(...)`).

SQL helpers:

-- post_reactions
create table if not exists public.post_reactions (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reaction text not null check (reaction in ('like','dislike')),
  created_at timestamptz not null default now(),
  unique (post_id, user_id)
);

-- post_comments
create table if not exists public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);

-- post_views
create table if not exists public.post_views (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (post_id, user_id)
);

Realtime

- In the Supabase dashboard, enable Realtime for tables: posts, post_reactions, post_comments.
- Under Database > Replication > Publications (supabase_realtime), add these tables if not already included.
  - Also include `post_views` so recommendations update when users view posts.
