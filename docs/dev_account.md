Dev Account (Elevated Abilities)

Goal

- Grant one specific user a developer account with additional privileges (e.g., delete any post or comment) while keeping normal users restricted by RLS.

Client setup

- In `lib/main.dart`, set your Supabase user UUID into the constant:

  const devUserId = 'a41f959f-fbfe-41ae-8daf-40beaa876635';

- The UI will show extra moderation controls (Delete for any post/comment) when the logged-in user matches `devUserId`.

Backend (Supabase) policies

- Ensure RLS is enabled on `posts` and `post_comments`.
- Add policies that permit the dev user to delete any row in addition to normal owner-based policies.

Example SQL

-- Allow owners to delete their posts (typical owner policy)
create policy if not exists posts_delete_own on public.posts
for delete using (auth.uid() = user_id);

-- Allow dev to delete any post
create policy if not exists posts_delete_dev on public.posts
for delete using (auth.uid() = 'a41f959f-fbfe-41ae-8daf-40beaa876635'::uuid);

-- Allow owners to delete their comments
create policy if not exists comments_delete_own on public.post_comments
for delete using (auth.uid() = user_id);

-- Allow dev to delete any comment
create policy if not exists comments_delete_dev on public.post_comments
for delete using (auth.uid() = 'a41f959f-fbfe-41ae-8daf-40beaa876635'::uuid);

Notes

- Replace YOUR_USER_ID_HERE in both the client constant and SQL with your actual user UUID.
- You can add similar policies for other tables if you want broader dev powers (e.g., reactions, views, friendships).
- Optionally, store the dev flag in `auth.users.app_metadata` and write policies based on `auth.jwt() -> 'app_metadata' ->> 'dev' = 'true'`. The hard-coded UUID approach is simplest.

