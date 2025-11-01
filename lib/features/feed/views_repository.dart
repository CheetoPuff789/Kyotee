import 'package:supabase_flutter/supabase_flutter.dart';

class ViewsRepository {
  final SupabaseClient _client;
  ViewsRepository(this._client);

  Future<void> recordView({required String postId, required String userId}) async {
    await _client.from('post_views').upsert({
      'post_id': postId,
      'user_id': userId,
    }, onConflict: 'post_id,user_id');
  }
}

