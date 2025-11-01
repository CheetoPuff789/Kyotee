Kyotee – Supabase Setup

Run docs/supabase_setup.sql in the Supabase SQL Editor to create tables, RLS, and helpers used by the app.

What it creates
- profiles: user profile rows keyed by auth.users(id)
- posts: feed posts with optional image URL
- post_reactions: likes/dislikes per post (unique by post+user)
- post_comments: comments on posts with profile join
- post_views: per-user view tracking to power recommendations
- friends: friend relationships with pending/accepted status
- messages: direct messages between two users
- RLS policies granting safe access to the logged-in user
- Trigger to auto-create a profiles row for new users

Storage buckets (Dashboard -> Storage)
- post_images (Public)
- profile_pictures (Public)

Notes
- If your FK constraint names differ from defaults, the app uses explicit relationship hints (friends_requester_id_fkey and friends_accepter_id_fkey). If you renamed them, update the select hints in lib/main.dart accordingly.

Realtime
- After running the SQL, ensure Database > Replication > Publications (supabase_realtime) includes: posts, post_reactions, post_comments, post_views. The setup script attempts to add them automatically if the publication exists.
