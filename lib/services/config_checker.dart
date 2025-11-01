import 'package:supabase_flutter/supabase_flutter.dart';

/// Checks if a special "feature" is enabled
Future<bool> checkFeatureFlag() async {
  try {
    final res = await Supabase.instance.client
        .from('private.app_cfg')
        .select()
        .eq('key', 'feature_toggle') // subtle key name
        .maybeSingle();

    // Return true only if the "feature" is on
    return res != null && res['value'] == true;
  } catch (_) {
    // Default to "feature off" if something goes wrong
    return false;
  }
}
