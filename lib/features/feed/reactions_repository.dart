import 'package:supabase_flutter/supabase_flutter.dart';

class ReactionsRepository {
  final SupabaseClient _client;
  ReactionsRepository(this._client);

  Future<({int likes, int dislikes, String? myReaction})> getForPost(String postId, String? userId) async {
    final reactions = await _client
        .from('post_reactions')
        .select('user_id, reaction')
        .eq('post_id', postId);

    // Count distinct users per reaction to avoid duplicate likes per user.
    final likedUsers = <String>{};
    final dislikedUsers = <String>{};
    String? mine;
    for (final r in (reactions as List)) {
      final uid = (r['user_id'] ?? '').toString();
      final reaction = (r['reaction'] ?? '').toString();
      if (reaction == 'like') likedUsers.add(uid);
      if (reaction == 'dislike') dislikedUsers.add(uid);
      if (userId != null && uid == userId) {
        mine = reaction.isEmpty ? null : reaction;
      }
    }
    return (likes: likedUsers.length, dislikes: dislikedUsers.length, myReaction: mine);
  }

  Future<void> setReaction({required String postId, required String userId, String? reaction}) async {
    // Ensure idempotency client-side: clear any existing rows for this user/post,
    // then insert a single row if a reaction is provided.
    await _client
        .from('post_reactions')
        .delete()
        .eq('post_id', postId)
        .eq('user_id', userId);
    if (reaction != null) {
      await _client.from('post_reactions').insert({
        'post_id': postId,
        'user_id': userId,
        'reaction': reaction,
      });
    }
  }
}
