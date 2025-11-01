import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRepository {
  final SupabaseClient _client;
  AdminRepository(this._client);

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim();
    final res = await _client
        .from('profiles')
        .select('id, username, email, avatar_url, banned')
        .or('username.ilike.%$q%,email.ilike.%$q%')
        .limit(50);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> setBanned({required String userId, required bool banned}) async {
    await _client.from('profiles').update({'banned': banned}).eq('id', userId);
  }

  Future<void> banUser({required String userId, required String email, DateTime? until}) async {
    await _client.from('profiles').update({
      'banned': true,
      'banned_until': until?.toIso8601String(),
    }).eq('id', userId);
    await _client.from('banned_emails').upsert({
      'email': email.toLowerCase(),
      'banned_until': until?.toIso8601String(),
    }, onConflict: 'email');
  }

  Future<void> unbanUser({required String userId, required String email}) async {
    await _client.from('profiles').update({
      'banned': false,
      'banned_until': null,
    }).eq('id', userId);
    await _client.from('banned_emails').delete().eq('email', email.toLowerCase());
  }
}
