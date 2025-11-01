import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/comment.dart';

class CommentsRepository {
  final SupabaseClient _client;
  CommentsRepository(this._client);

  Future<List<Comment>> fetchForPost(String postId) async {
    final data = await _client
        .from('post_comments')
        .select('id, post_id, user_id, content, created_at, profiles(username, avatar_url)')
        .eq('post_id', postId)
        .order('created_at');
    final list = (data as List).cast<Map<String, dynamic>>();
    return list.map(Comment.fromMap).toList();
  }

  Future<void> addComment({required String postId, required String userId, required String content}) async {
    await _client.from('post_comments').insert({
      'post_id': postId,
      'user_id': userId,
      'content': content,
    });
  }

  Future<void> deleteComment(String commentId) async {
    await _client.from('post_comments').delete().eq('id', commentId);
  }

  Future<void> updateComment({required String commentId, required String content}) async {
    await _client.from('post_comments').update({'content': content}).eq('id', commentId);
  }
}
