import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/post.dart';

class PostsRepository {
  final SupabaseClient _client;
  PostsRepository(this._client);

  static const _postColumns =
      'id, content, image_url, created_at, user_id, profiles(username, avatar_url, banned)';

  Future<List<Post>> fetchLatest() async {
    final data = await _client
        .from('posts')
        .select(_postColumns)
        .order('created_at', ascending: false);
    final list = (data as List).cast<Map<String, dynamic>>();
    final posts = list.map(Post.fromMap).toList();
    // Exclude banned authors
    return posts.where((p) => !p.banned).toList();
  }

  Future<List<Post>> fetchLatestPage({int limit = 10, int offset = 0}) async {
    final data = await _client
        .from('posts')
        .select(_postColumns)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    final list = (data as List).cast<Map<String, dynamic>>();
    final posts = list.map(Post.fromMap).toList();
    return posts.where((p) => !p.banned).toList();
  }

  Future<List<Post>> fetchRecommended(String userId) async {
    // Build author preference from user's likes/dislikes
    final prefsData = await _client
        .from('post_reactions')
        .select('reaction, posts(user_id)')
        .eq('user_id', userId);
    final prefs = <String, int>{};
    for (final row in (prefsData as List)) {
      final post = row['posts'] as Map<String, dynamic>?;
      final authorId = post != null ? post['user_id']?.toString() : null;
      if (authorId == null) continue;
      final r = (row['reaction'] ?? '').toString();
      prefs[authorId] =
          (prefs[authorId] ?? 0) +
          (r == 'like'
              ? 1
              : r == 'dislike'
              ? -1
              : 0);
    }

    // Build views count per author for this user
    final viewsData = await _client
        .from('post_views')
        .select('posts(user_id)')
        .eq('user_id', userId);
    final viewsByAuthor = <String, int>{};
    for (final row in (viewsData as List)) {
      final post = row['posts'] as Map<String, dynamic>?;
      final authorId = post != null ? post['user_id']?.toString() : null;
      if (authorId == null) continue;
      viewsByAuthor[authorId] = (viewsByAuthor[authorId] ?? 0) + 1;
    }

    final latest = await fetchLatest();
    // Filter: hide authors with negative score but only after 9 views
    final filtered = latest.where((p) {
      final score = prefs[p.userId] ?? 0;
      final views = viewsByAuthor[p.userId] ?? 0;
      if (views >= 9 && score < 0) return false; // hide
      return true;
    }).toList();

    filtered.sort((a, b) {
      final sa = prefs[a.userId] ?? 0;
      final sb = prefs[b.userId] ?? 0;
      if (sb != sa) return sb.compareTo(sa); // higher score first
      return b.createdAt.compareTo(a.createdAt); // newest next
    });
    return filtered;
  }

  Future<List<Post>> fetchRecommendedPage(
    String userId, {
    int limit = 10,
    int offset = 0,
  }) async {
    // Build author preference from user's likes/dislikes
    final prefsData = await _client
        .from('post_reactions')
        .select('reaction, posts(user_id)')
        .eq('user_id', userId);
    final prefs = <String, int>{};
    for (final row in (prefsData as List)) {
      final post = row['posts'] as Map<String, dynamic>?;
      final authorId = post != null ? post['user_id']?.toString() : null;
      if (authorId == null) continue;
      final r = (row['reaction'] ?? '').toString();
      prefs[authorId] =
          (prefs[authorId] ?? 0) +
          (r == 'like'
              ? 1
              : r == 'dislike'
              ? -1
              : 0);
    }

    // Build views count per author for this user
    final viewsData = await _client
        .from('post_views')
        .select('posts(user_id)')
        .eq('user_id', userId);
    final viewsByAuthor = <String, int>{};
    for (final row in (viewsData as List)) {
      final post = row['posts'] as Map<String, dynamic>?;
      final authorId = post != null ? post['user_id']?.toString() : null;
      if (authorId == null) continue;
      viewsByAuthor[authorId] = (viewsByAuthor[authorId] ?? 0) + 1;
    }

    final latestPage = await fetchLatestPage(limit: limit, offset: offset);
    final filtered = latestPage.where((p) {
      final score = prefs[p.userId] ?? 0;
      final views = viewsByAuthor[p.userId] ?? 0;
      if (views >= 9 && score < 0) return false; // hide
      return true;
    }).toList();

    filtered.sort((a, b) {
      final sa = prefs[a.userId] ?? 0;
      final sb = prefs[b.userId] ?? 0;
      if (sb != sa) return sb.compareTo(sa); // higher score first
      return b.createdAt.compareTo(a.createdAt); // newest next
    });
    return filtered;
  }

  Future<Post?> fetchById(String id) async {
    final data = await _client
        .from('posts')
        .select(_postColumns)
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    final post = Post.fromMap((data as Map<String, dynamic>));
    return post.banned ? null : post;
  }
}
