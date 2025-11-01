import 'package:supabase_flutter/supabase_flutter.dart';

class CommentLikesRepository {
  final SupabaseClient _client;
  CommentLikesRepository(this._client);

  // Returns (count, likedByMe). If table missing, returns (0, false).
  Future<({int count, bool likedByMe})> getForComment(String commentId, String? userId) async {
    try {
      final rows = await _client
          .from('comment_likes')
          .select('user_id')
          .eq('comment_id', commentId);
      final list = (rows as List).cast<Map<String, dynamic>>();
      final count = list.length;
      final likedByMe = userId != null && list.any((r) => (r['user_id']?.toString() ?? '') == userId);
      return (count: count, likedByMe: likedByMe);
    } catch (_) {
      return (count: 0, likedByMe: false);
    }
  }

  Future<void> setLike({required String commentId, required String userId, required bool like}) async {
    try {
      if (like) {
        // Insert if not exists (client-side idempotency)
        await _client.from('comment_likes').insert({
          'comment_id': commentId,
          'user_id': userId,
        });
      } else {
        await _client
            .from('comment_likes')
            .delete()
            .eq('comment_id', commentId)
            .eq('user_id', userId);
      }
    } catch (_) {
      // Silently ignore; UI will restore via reload
    }
  }
}

class CommentRepliesRepository {
  final SupabaseClient _client;
  CommentRepliesRepository(this._client);

  Future<List<Map<String, dynamic>>> fetchForComment(String commentId) async {
    try {
      final data = await _client
          .from('comment_replies')
          .select('id, comment_id, user_id, content, created_at, profiles(username, avatar_url)')
          .eq('comment_id', commentId)
          .order('created_at');
      final list = (data as List).cast<Map<String, dynamic>>();
      return list
          .map((m) => {
                'id': m['id']?.toString(),
                'comment_id': m['comment_id']?.toString(),
                'user_id': m['user_id']?.toString(),
                'content': (m['content'] ?? '').toString(),
                'created_at': m['created_at'],
                'username': ((m['profiles'] as Map<String, dynamic>?)?['username'] ?? 'Unknown').toString(),
                'avatar_url': (m['profiles'] as Map<String, dynamic>?)?['avatar_url'] as String?,
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addReply({required String commentId, required String userId, required String content}) async {
    await _client.from('comment_replies').insert({
      'comment_id': commentId,
      'user_id': userId,
      'content': content,
    });
  }
}

