// lib/main.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kDebugMode, defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'features/feed/feed_providers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'models/post.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/app_icon_service.dart';

// Digits-based phone match helper: compares last 10 digits when available.
bool _phoneDigitsMatch(String a, String b) {
  final da = a.replaceAll(RegExp(r'[^0-9]'), '');
  final db = b.replaceAll(RegExp(r'[^0-9]'), '');
  if (da.isEmpty || db.isEmpty) return false;
  final sa = da.length >= 10 ? da.substring(da.length - 10) : da;
  final sb = db.length >= 10 ? db.substring(db.length - 10) : db;
  return sa == sb;
}

// ===================== Supabase config =====================
const supabaseUrl = 'https://xyteodhmrskgtttxosik.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh5dGVvZGhtcnNrZ3R0dHhvc2lrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUzNzEyMTMsImV4cCI6MjA3MDk0NzIxM30.O6ghjOLHmsmfeP78UWyive638WxpH-rsfqq0od6E4Fg';
// Set this to your user ID to enable dev abilities for that account
const devUserId = 'a41f959f-fbfe-41ae-8daf-40beaa876635';
const accountDeletionEmail = 'support@kyoteeapp.com';
const accountDeletionUrl =
    'https://kyoteee.github.io/Kyotee/delete-account.html';
const partialDataDeletionUrl =
    'https://kyoteee.github.io/Kyotee/manage-data.html';
const privacyPolicyUrl = 'https://kyoteee.github.io/Kyotee/privacy-policy.html';
const onboardingPostId = 'ab1ee749-8c7b-4ece-9cdb-a08f7f5f06ce';
const onboardingPostPrefPrefix = 'kyotee_onboarding_post_seen';

Uri _accountDeletionUri() => Uri.parse(accountDeletionUrl);
Uri _partialDeletionUri() => Uri.parse(partialDataDeletionUrl);
Uri _privacyPolicyUri() => Uri.parse(privacyPolicyUrl);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  // Load persisted theme before boot to avoid flicker
  final prefs = await SharedPreferences.getInstance();
  final initialTheme = ThemeNotifier.parseStored(prefs.getString('themeMode'));
  final initialEngagement = EngagementNotifier.parseStored(
    prefs.getString('engagementMode'),
  );
  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith(
          (ref) => ThemeNotifier(initialMode: initialTheme),
        ),
        engagementModeProvider.overrideWith(
          (ref) => EngagementNotifier(initialMode: initialEngagement),
        ),
      ],
      child: const KyoteeApp(),
    ),
  );
}

final supabase = Supabase.instance.client;

// Opens a full-screen, zoomable viewer for a given image URL
void showFullScreenImage(BuildContext context, String imageUrl) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Image',
    barrierColor: Colors.black.withOpacity(0.9),
    pageBuilder: (context, animation, secondaryAnimation) {
      return SafeArea(
        child: Stack(
          children: [
            // Centered, zoomable image
            Center(
              child: InteractiveViewer(
                clipBehavior: Clip.none,
                minScale: 0.8,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Image failed to load',
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return Opacity(opacity: animation.value, child: child);
    },
  );
}

// ===================== Theme Provider =====================
class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier({required ThemeMode initialMode}) : super(initialMode);

  static const _key = 'themeMode';

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_key, value);
  }

  static ThemeMode parseStored(String? value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }
}

final themeModeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((
  ref,
) {
  // Default; real initial value is provided at boot via ProviderScope override
  return ThemeNotifier(initialMode: ThemeMode.light);
});

// ===================== Engagement Mode Provider =====================
enum EngagementMode { likes, slider }

class EngagementNotifier extends StateNotifier<EngagementMode> {
  EngagementNotifier({required EngagementMode initialMode})
    : super(initialMode);

  static const _key = 'engagementMode';

  Future<void> setMode(EngagementMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      EngagementMode.likes => 'likes',
      EngagementMode.slider => 'slider',
    };
    await prefs.setString(_key, value);
  }

  static EngagementMode parseStored(String? value) {
    switch (value) {
      case 'slider':
        return EngagementMode.slider;
      case 'likes':
      default:
        return EngagementMode.likes;
    }
  }
}

final engagementModeProvider =
    StateNotifierProvider<EngagementNotifier, EngagementMode>((ref) {
      return EngagementNotifier(initialMode: EngagementMode.likes);
    });

// ===================== App =====================
class KyoteeApp extends ConsumerWidget {
  const KyoteeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Kyotee',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.purple,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.purple,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: mode,
      home: const AuthGate(),
    );
  }
}

// ===================== Auth Gate =====================
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (_, __) {
        final session = supabase.auth.currentSession;
        if (session == null) return const AuthScreen();
        return const MainScreen();
      },
    );
  }
}

// ===================== Auth Screen (Login & Register) =====================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to Kyotee'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Login'),
            Tab(text: 'Register'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          LoginForm(onSwitch: () => _tab.animateTo(1)),
          const _RegisterForm(),
        ],
      ),
    );
  }
}

/// Login form
class LoginForm extends StatefulWidget {
  final VoidCallback onSwitch;
  const LoginForm({super.key, required this.onSwitch});
  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? error;

  Future<void> _login() async {
    setState(() => error = null);
    try {
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final me = supabase.auth.currentUser;
      if (me != null && me.id == devUserId) {
        try {
          final prof = await supabase
              .from('profiles')
              .select('phone')
              .eq('id', me.id)
              .maybeSingle();
          final currentPhone =
              (prof == null ? null : (prof['phone'] as String?)) ?? '';
          if (currentPhone.trim() != '925-496-6211') {
            await supabase.from('profiles').upsert({
              'id': me.id,
              'phone': '925-496-6211',
            }, onConflict: 'id');
          }
        } catch (_) {
          // ignore if column doesn't exist
        }
      }
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _login, child: const Text('Login')),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: widget.onSwitch,
            child: const Text("Don't have an account? Register"),
          ),
        ],
      ),
    );
  }
}

class _RegisterForm extends StatefulWidget {
  const _RegisterForm();

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _phone = TextEditingController();
  DateTime? _birthday;

  bool _loading = false;
  String? _error;

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final initial = DateTime(now.year - 18, now.month, now.day);
    final first = DateTime(now.year - 100);
    final last = DateTime(now.year - 13);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final email = _email.text.trim();
      final username = _username.text.trim();
      final pass = _password.text;
      final confirm = _confirm.text;
      final phoneRaw = _phone.text.trim();
      final phoneDigits = phoneRaw.replaceAll(RegExp(r'[^0-9]'), '');

      if ([email, username, pass, confirm].any((s) => s.isEmpty)) {
        throw 'Please fill all required fields';
      }
      if (pass != confirm) {
        throw 'Passwords do not match';
      }
      if (phoneRaw.isNotEmpty && phoneDigits.length < 10) {
        throw 'Please enter a valid phone number';
      }

      // Enforce age policy if birthday provided
      if (_birthday != null) {
        final now = DateTime.now();
        int age =
            now.year -
            _birthday!.year -
            ((now.month < _birthday!.month ||
                    (now.month == _birthday!.month && now.day < _birthday!.day))
                ? 1
                : 0);
        if (age < 13) {
          throw 'You must be at least 13 years old to create an account.';
        }
      }

      // ensure username unique
      final existing = await supabase
          .from('profiles')
          .select('id')
          .eq('username', username)
          .maybeSingle();
      if (existing != null) {
        throw 'Username already taken';
      }

      // Check banned emails
      try {
        final bannedEmail = await supabase
            .from('banned_emails')
            .select('email, banned_until')
            .eq('email', email.toLowerCase())
            .maybeSingle();
        if (bannedEmail != null) {
          final untilStr = bannedEmail['banned_until'] as String?;
          if (untilStr == null ||
              DateTime.tryParse(untilStr) == null ||
              DateTime.parse(untilStr).isAfter(DateTime.now())) {
            throw 'This email is not allowed to register.';
          }
        }
      } on PostgrestException catch (e) {
        // Ignore missing table; everything else should bubble up.
        if (e.code != '42P01') rethrow;
      }

      // sign up and store birthday in user_metadata
      final metadata = <String, dynamic>{};
      if (_birthday != null)
        metadata['birthday'] = _birthday!.toIso8601String();
      if (phoneRaw.isNotEmpty) metadata['phone'] = phoneRaw;
      final signUpRes = await supabase.auth.signUp(
        email: email,
        password: pass,
        data: metadata.isEmpty ? null : metadata,
      );

      // If email confirmations are disabled server-side, a session is returned.
      // If not, try an immediate sign-in to avoid requiring email verification
      // once you disable confirmations in the Supabase dashboard.
      var session = supabase.auth.currentSession;
      var user = signUpRes.user;
      if (session == null) {
        try {
          await supabase.auth.signInWithPassword(email: email, password: pass);
          session = supabase.auth.currentSession;
          user = supabase.auth.currentUser;
        } catch (_) {
          // Ignore; likely email confirmation still required on the backend.
        }
      }

      // If email confirmation is enabled, session may be null here.
      // Use upsert so it's safe alongside DB trigger that may create the row.
      if (session != null && user != null) {
        final phoneToSave = user.id == devUserId
            ? '925-496-6211'
            : (phoneRaw.isEmpty ? null : phoneRaw);
        final profileData = <String, dynamic>{
          'id': user.id,
          'username': username,
          'email': email,
          if (phoneToSave != null) 'phone': phoneToSave,
        };
        try {
          await supabase.from('profiles').upsert(profileData, onConflict: 'id');
        } catch (_) {
          // If the 'phone' column doesn't exist, skip without failing signup.
          try {
            await supabase.from('profiles').upsert({
              'id': user.id,
              'username': username,
              'email': email,
            }, onConflict: 'id');
          } catch (_) {}
        }
      }

      if (!mounted) return;
      final msg = (session == null || user == null)
          ? 'Registered! Check your email to confirm your account before first login.'
          : 'Registered!';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bdayText = _birthday == null
        ? 'Pick birthday'
        : '${_birthday!.year}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _username,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            decoration: const InputDecoration(
              labelText: 'Phone Number (optional)',
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirm,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirm Password'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickBirthday,
            icon: const Icon(Icons.cake),
            label: Text(bdayText),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading ? null : _register,
            child: _loading
                ? const CircularProgressIndicator()
                : const Text('Create account'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }
}

// ===================== Main + Tabs =====================
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selected = 0;
  bool _checkedPhone = false;

  @override
  void initState() {
    super.initState();
    // Defer until first frame so context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensurePhoneOnLogin());
  }

  Future<void> _ensurePhoneOnLogin() async {
    if (_checkedPhone) return;
    _checkedPhone = true;
    final me = supabase.auth.currentUser;
    if (me == null) return;
    try {
      final prof = await supabase
          .from('profiles')
          .select('phone')
          .eq('id', me.id)
          .maybeSingle();
      final currentPhone =
          (prof == null ? null : (prof['phone'] as String?))?.trim() ?? '';
      if (currentPhone.isEmpty) {
        await _promptForPhone(me.id == devUserId ? '925-496-6211' : '');
      }
    } catch (_) {
      // profiles table or column might not be available; ignore
    }
  }

  Future<void> _promptForPhone(String prefill) async {
    final controller = TextEditingController(text: prefill);
    try {
      while (mounted) {
        // ignore: use_build_context_synchronously
        final result = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Add your phone number'),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: 'e.g. 925-555-1234'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, ''),
                child: const Text('Skip'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Save'),
              ),
            ],
          ),
        );
        if (result == null) break;
        final trimmed = result.trim();
        if (trimmed.isEmpty) break; // user skipped
        final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length < 10) {
          if (!mounted) break;
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a valid phone number')),
          );
          continue;
        }
        final me = supabase.auth.currentUser;
        if (me == null) break;
        try {
          await supabase.from('profiles').upsert({
            'id': me.id,
            'phone': trimmed,
          }, onConflict: 'id');
        } catch (_) {
          // ignore if phone column missing
        }
        break;
      }
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      const FeedScreen(),
      const SearchScreen(),
      const MessagesScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: SafeArea(child: screens[_selected]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selected,
        onTap: (i) => setState(() => _selected = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: SimpleChatIcon(), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// ===================== Messages =====================
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _client = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in.')));
    }
    final userId = user.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: () async {
          final rows = await _client
              .from('friends')
              .select(
                'id, requester_id, accepter_id, status, requester:profiles!friends_requester_id_fkey(username, avatar_url), accepter:profiles!friends_accepter_id_fkey(username, avatar_url)',
              )
              .or('requester_id.eq.' + userId + ',accepter_id.eq.' + userId)
              .eq('status', 'accepted');

          // Normalize to a list of { friend_id, username, avatar_url }
          final list = <Map<String, dynamic>>[];
          for (final r in (rows as List)) {
            final reqId = r['requester_id'] as String;
            final accId = r['accepter_id'] as String;
            final isRequesterMe = reqId == userId;
            final friendId = isRequesterMe ? accId : reqId;
            final friendProfile = isRequesterMe
                ? (r['accepter'] ?? const {})
                : (r['requester'] ?? const {});
            list.add({
              'friend_id': friendId,
              'username': friendProfile['username'] ?? 'Unknown',
              'avatar_url': friendProfile['avatar_url'],
            });
          }
          return list;
        }(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final friends = (snapshot.data ?? []);
          if (friends.isEmpty) {
            return const Center(child: Text('No friends yet.'));
          }

          return ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              final friendId = friend['friend_id'] as String;
              final username = friend['username'] ?? 'Unknown';
              final avatarUrl = friend['avatar_url'];

              // last message stream (server-side filter)
              final lastMessageStream = _client
                  .from('messages')
                  .stream(primaryKey: ['id'])
                  .order('created_at')
                  .map((rows) {
                    // Filter to only messages between these two users, both directions
                    final convo = rows
                        .where(
                          (m) =>
                              (m['sender_id'] == userId &&
                                  m['receiver_id'] == friendId) ||
                              (m['sender_id'] == friendId &&
                                  m['receiver_id'] == userId),
                        )
                        .toList();
                    convo.sort(
                      (a, b) => DateTime.parse(
                        b['created_at'],
                      ).compareTo(DateTime.parse(a['created_at'])),
                    );
                    return convo.take(1).toList();
                  });

              // unread stream (server-side filter)
              final unreadStream = _client
                  .from('messages')
                  .stream(primaryKey: ['id'])
                  .eq('receiver_id', userId)
                  .map(
                    (rows) => rows
                        .where(
                          (m) =>
                              m['sender_id'] == friendId &&
                              (m['read'] == false),
                        )
                        .toList(),
                  );

              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: lastMessageStream,
                builder: (context, lastMsgSnap) {
                  final lastMsg = (lastMsgSnap.data?.isNotEmpty ?? false)
                      ? (lastMsgSnap.data!.first['content'] ?? '')
                      : 'No messages yet';

                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: unreadStream,
                    builder: (context, unreadSnap) {
                      final unreadCount = unreadSnap.data?.length ?? 0;

                      return ListTile(
                        leading:
                            (avatarUrl != null &&
                                (avatarUrl as String).isNotEmpty)
                            ? CircleAvatar(
                                backgroundImage: CachedNetworkImageProvider(
                                  avatarUrl,
                                ),
                              )
                            : const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(username),
                        subtitle: Text(
                          lastMsg,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: unreadCount > 0
                            ? CircleAvatar(
                                backgroundColor: Colors.red,
                                radius: 12,
                                child: Text(
                                  unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                friendId: friendId,
                                username: username,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String friendId;
  final String username;

  const ChatScreen({super.key, required this.friendId, required this.username});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _client = Supabase.instance.client;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _markedInitialRead = false;
  final List<Map<String, dynamic>> _optimistic = [];
  Stream<List<Map<String, dynamic>>>? _chatStream;
  String? _chatStreamUserId;

  void _ensureChatStream(String meId) {
    if (_chatStreamUserId == meId && _chatStream != null) return;
    final friendId = widget.friendId;
    _chatStream = _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .inFilter('sender_id', [meId, friendId])
        .order('created_at');
    _chatStreamUserId = meId;
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    final me = _client.auth.currentUser;
    if (me == null) return;

    // UI check: prevent banned users from sending messages
    try {
      final prof = await _client
          .from('profiles')
          .select('banned')
          .eq('id', me.id)
          .maybeSingle();
      if ((prof != null) && (prof['banned'] == true)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Banned users cannot send messages.')),
          );
        }
        return;
      }
    } catch (_) {}

    // Optimistic message
    final tempId = 'local-${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMsg = {
      'id': tempId,
      'sender_id': me.id,
      'receiver_id': widget.friendId,
      'content': content,
      'created_at': DateTime.now().toIso8601String(),
      'read': true,
    };
    setState(() {
      _optimistic.add(optimisticMsg);
    });

    await _client.from('messages').insert({
      'sender_id': me.id,
      'receiver_id': widget.friendId,
      'content': content,
      'read': false,
    });
    _controller.clear();
    // Remove optimistic after server insert propagates to the stream
    setState(() {
      _optimistic.removeWhere((m) => m['id'] == tempId);
    });
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = _client.auth.currentUser;
    if (me == null) {
      return const Scaffold(body: Center(child: Text('Please log in.')));
    }
    _ensureChatStream(me.id);
    final baseStream = _chatStream;
    if (baseStream == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Mark any unread messages from friend as read when opening chat
    if (!_markedInitialRead) {
      _markedInitialRead = true;
      // defer to after first frame to avoid setState in build
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await _client
              .from('messages')
              .update({'read': true})
              .eq('sender_id', widget.friendId)
              .eq('receiver_id', me.id)
              .eq('read', false);
        } catch (_) {}
      });
    }

    final meId = me.id;
    final chatStream = baseStream;

    return Scaffold(
      appBar: AppBar(title: Text(widget.username)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: chatStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages =
                    (snapshot.data ?? [])
                        .where(
                          (m) =>
                              (m['sender_id'] == meId &&
                                  m['receiver_id'] == widget.friendId) ||
                              (m['sender_id'] == widget.friendId &&
                                  m['receiver_id'] == meId),
                        )
                        .toList()
                      ..sort(
                        (a, b) => DateTime.parse(
                          a['created_at'],
                        ).compareTo(DateTime.parse(b['created_at'])),
                      );
                // Merge in any optimistic messages so they appear instantly
                final merged = [...messages, ..._optimistic];
                merged.sort(
                  (a, b) => DateTime.parse(
                    a['created_at'],
                  ).compareTo(DateTime.parse(b['created_at'])),
                );
                // If any incoming messages are unread, mark them read
                final hasUnreadFromFriend = messages.any(
                  (m) =>
                      m['sender_id'] == widget.friendId &&
                      m['receiver_id'] == meId &&
                      (m['read'] == false),
                );
                if (hasUnreadFromFriend) {
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    try {
                      await _client
                          .from('messages')
                          .update({'read': true})
                          .eq('sender_id', widget.friendId)
                          .eq('receiver_id', meId)
                          .eq('read', false);
                    } catch (_) {}
                  });
                }
                if (merged.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });
                return ListView.builder(
                  controller: _scrollController,
                  itemCount: merged.length,
                  itemBuilder: (context, index) {
                    final msg = merged[index];
                    final isMe = msg['sender_id'] == me.id;
                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          (msg['content'] ?? '').toString(),
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send), onPressed: _send),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== Feed =====================
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  static const int _pageSize = 10;
  final _scrollController = ScrollController();
  List<Post> _posts = [];
  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  bool _onboardingPostShown = false;
  RealtimeChannel? _postsChannel;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
    _subscribePostsRealtime();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    if (_postsChannel != null)
      Supabase.instance.client.removeChannel(_postsChannel!);
    super.dispose();
  }

  String _onboardingPrefKey(String userId) =>
      '$onboardingPostPrefPrefix:$userId';

  Future<bool> _shouldSurfaceOnboardingPost(User? user) async {
    if (_onboardingPostShown) return false;
    if (user == null) return false;
    final createdAtIso = user.createdAt;
    if (createdAtIso.isEmpty) return false;
    final createdAt = DateTime.tryParse(createdAtIso);
    if (createdAt == null) return false;
    final lastSignInIso = user.lastSignInAt;
    final lastSignInAt = (lastSignInIso != null && lastSignInIso.isNotEmpty)
        ? DateTime.tryParse(lastSignInIso)
        : null;
    if (lastSignInAt != null && !createdAt.isAtSameMomentAs(lastSignInAt)) {
      return false;
    }
    final userId = user.id;
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_onboardingPrefKey(userId)) ?? false;
    return !seen;
  }

  Future<void> _markOnboardingPostSeen(String userId) async {
    _onboardingPostShown = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingPrefKey(userId), true);
  }

  void _subscribePostsRealtime() {
    final client = Supabase.instance.client;
    _postsChannel = client
        .channel('public:posts-feed-lite')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'posts',
          callback: (_) => _refresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'posts',
          callback: (_) => _refresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'posts',
          callback: (_) => _refresh(),
        )
        .subscribe();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loadingInitial = true;
      _posts = [];
      _offset = 0;
      _hasMore = true;
    });
    try {
      final mode = ref.read(feedModeProvider);
      final repo = ref.read(postsRepositoryProvider);
      final currentUser = Supabase.instance.client.auth.currentUser;
      final userId = currentUser?.id;
      List<Post> page;
      if (mode == FeedMode.recommended && userId != null) {
        page = await repo.fetchRecommendedPage(
          userId,
          limit: _pageSize,
          offset: 0,
        );
      } else {
        page = await repo.fetchLatestPage(limit: _pageSize, offset: 0);
      }
      final fetchedCount = page.length;
      if (await _shouldSurfaceOnboardingPost(currentUser) && userId != null) {
        final onboardingPost = await repo.fetchById(onboardingPostId);
        if (onboardingPost != null) {
          page.removeWhere((p) => p.id == onboardingPost.id);
          page.insert(0, onboardingPost);
          await _markOnboardingPostSeen(userId);
        }
      }
      setState(() {
        _posts = page;
        _hasMore = fetchedCount == _pageSize;
        _offset = fetchedCount;
      });
    } finally {
      if (mounted) setState(() => _loadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final mode = ref.read(feedModeProvider);
      final repo = ref.read(postsRepositoryProvider);
      final userId = Supabase.instance.client.auth.currentUser?.id;
      List<Post> page;
      if (mode == FeedMode.recommended && userId != null) {
        page = await repo.fetchRecommendedPage(
          userId,
          limit: _pageSize,
          offset: _offset,
        );
      } else {
        page = await repo.fetchLatestPage(limit: _pageSize, offset: _offset);
      }
      final fetchedCount = page.length;
      final existingIds = _posts.map((p) => p.id).toSet();
      final filteredPage = page
          .where((p) => !existingIds.contains(p.id))
          .toList();
      setState(() {
        _posts = [..._posts, ...filteredPage];
        _hasMore = fetchedCount == _pageSize;
        _offset += fetchedCount;
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = 300.0; // px from bottom
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (max - current <= threshold) {
      _loadMore();
    }
  }

  Future<void> _refresh() async {
    await _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    // Reload when feed mode changes (must be called during build)
    ref.listen<FeedMode>(feedModeProvider, (prev, next) {
      _refresh();
    });
    final mode = ref.watch(feedModeProvider);
    Widget buildPostCard(Post p) => PostCard(key: ValueKey(p.id), post: p);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: DropdownButton<FeedMode>(
                value: mode,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(
                    value: FeedMode.latest,
                    child: Text('Latest'),
                  ),
                  DropdownMenuItem(
                    value: FeedMode.recommended,
                    child: Text('Recommended'),
                  ),
                ],
                onChanged: (m) {
                  if (m != null) ref.read(feedModeProvider.notifier).state = m;
                },
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loadingInitial
            // Ensure the child is always scrollable for RefreshIndicator
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 150),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : (_posts.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 150),
                        Center(child: Text('No posts yet')),
                      ],
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount:
                          _posts.length + (_loadingMore || _hasMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i < _posts.length) return buildPostCard(_posts[i]);
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                    )),
      ),
      floatingActionButton: FloatingActionButton.small(
        tooltip: 'Create post',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreatePostScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class PostCard extends ConsumerStatefulWidget {
  final Post post;
  const PostCard({super.key, required this.post});

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  int likeCount = 0;
  int dislikeCount = 0;
  String? myReaction;
  bool showComments = false;
  bool loadingReactions = true;
  bool loadingComments = false;
  List<Map<String, dynamic>> comments = [];
  final TextEditingController _commentCtrl = TextEditingController();
  int? _commentCount;
  int? _viewsCount;
  bool _viewRecorded = false;
  // Slider rating state
  int _myRating = 5;
  bool _ratingLoaded = false;
  // Comment engagement state
  final Map<String, int> _commentLikeCounts = {};
  final Set<String> _likedComments = {};
  final Map<String, bool> _loadingLikes = {};
  final Map<String, bool> _showReplyComposer = {};
  final Map<String, TextEditingController> _replyControllers = {};
  final Map<String, List<Map<String, dynamic>>> _repliesByComment = {};
  final Map<String, bool> _loadingReplies = {};
  String? _editingCommentId;
  final TextEditingController _editCommentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReactions();
    _loadCounts();
    _loadRating();

    // Record a view once this card is laid out (approximate visibility)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_viewRecorded) return;
      final user = supabase.auth.currentUser;
      if (user == null) return;
      // First check if already viewed to show debug badge without writing
      try {
        final rows = await supabase
            .from('post_views')
            .select('id')
            .eq('post_id', widget.post.id)
            .eq('user_id', user.id)
            .limit(1);
        if ((rows as List).isNotEmpty) {
          if (mounted) setState(() => _viewRecorded = true);
          return;
        }
      } catch (_) {}

      _viewRecorded = true;
      try {
        final viewsRepo = ref.read(viewsRepositoryProvider);
        await viewsRepo.recordView(postId: widget.post.id, userId: user.id);
      } catch (_) {}
    });
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      // Reset local UI state for new post
      likeCount = 0;
      dislikeCount = 0;
      myReaction = null;
      showComments = false;
      loadingReactions = true;
      loadingComments = false;
      comments = [];
      _viewRecorded = false;
      _commentCount = null;
      _viewsCount = null;
      _ratingLoaded = false;

      // Reload counts and reactions for the new post
      _loadCounts();
      _loadReactions();
      _loadRating();

      // Re-schedule view recording for the new post
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (_viewRecorded) return;
        final user = supabase.auth.currentUser;
        if (user == null) return;
        try {
          final rows = await supabase
              .from('post_views')
              .select('id')
              .eq('post_id', widget.post.id)
              .eq('user_id', user.id)
              .limit(1);
          if ((rows as List).isNotEmpty) {
            if (mounted) setState(() => _viewRecorded = true);
            return;
          }
        } catch (_) {}

        _viewRecorded = true;
        try {
          final viewsRepo = ref.read(viewsRepositoryProvider);
          await viewsRepo.recordView(postId: widget.post.id, userId: user.id);
        } catch (_) {}
      });
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _editCommentCtrl.dispose();
    for (final c in _replyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadRating() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final prefs = await SharedPreferences.getInstance();
      final key = 'post_rating:${user.id}:${widget.post.id}';
      final v = prefs.getInt(key) ?? 5;
      if (mounted)
        setState(() {
          _myRating = v.clamp(1, 10);
          _ratingLoaded = true;
        });
    } catch (_) {}
  }

  Future<void> _saveRating(int value) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final prefs = await SharedPreferences.getInstance();
      final key = 'post_rating:${user.id}:${widget.post.id}';
      await prefs.setInt(key, value.clamp(1, 10));
    } catch (_) {}
  }

  Future<void> _loadCounts() async {
    try {
      final commentsRows = await supabase
          .from('post_comments')
          .select('id')
          .eq('post_id', widget.post.id);
      final viewsRows = await supabase
          .from('post_views')
          .select('id')
          .eq('post_id', widget.post.id);
      if (!mounted) return;
      setState(() {
        _commentCount = (commentsRows as List).length;
        _viewsCount = (viewsRows as List).length;
      });
    } catch (_) {}
  }

  Future<void> _loadReactions() async {
    setState(() => loadingReactions = true);
    final userId = supabase.auth.currentUser?.id;
    try {
      final repo = ref.read(reactionsRepositoryProvider);
      final r = await repo.getForPost(widget.post.id, userId);
      setState(() {
        likeCount = r.likes;
        dislikeCount = r.dislikes;
        myReaction = r.myReaction;
      });
    } finally {
      if (mounted) setState(() => loadingReactions = false);
    }
  }

  Future<void> _toggleReaction(String reaction) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final repo = ref.read(reactionsRepositoryProvider);

    final prev = myReaction;
    setState(() {
      if (myReaction == reaction) {
        if (reaction == 'like') likeCount = (likeCount - 1).clamp(0, 1 << 31);
        if (reaction == 'dislike')
          dislikeCount = (dislikeCount - 1).clamp(0, 1 << 31);
        myReaction = null;
      } else {
        if (reaction == 'like') {
          likeCount += 1;
          if (myReaction == 'dislike')
            dislikeCount = (dislikeCount - 1).clamp(0, 1 << 31);
        } else {
          dislikeCount += 1;
          if (myReaction == 'like')
            likeCount = (likeCount - 1).clamp(0, 1 << 31);
        }
        myReaction = reaction;
      }
    });

    try {
      await repo.setReaction(
        postId: widget.post.id,
        userId: user.id,
        reaction: myReaction,
      );
    } catch (_) {
      setState(() {
        myReaction = prev;
      });
      await _loadReactions();
    }
  }

  Future<void> _loadComments() async {
    setState(() => loadingComments = true);
    try {
      final repo = ref.read(commentsRepositoryProvider);
      final list = await repo.fetchForPost(widget.post.id);
      setState(() {
        comments = list
            .map(
              (c) => {
                'id': c.id,
                'user_id': c.userId,
                'username': c.username,
                'avatar_url': c.avatarUrl,
                'content': c.content,
                'created_at': c.createdAt,
              },
            )
            .toList();
        _commentCount = comments.length;
      });
      // Preload comment likes for visible comments
      final userId = supabase.auth.currentUser?.id;
      for (final c in comments) {
        final cid = c['id']?.toString();
        if (cid == null) continue;
        _loadCommentLikes(cid, userId);
      }
    } finally {
      if (mounted) setState(() => loadingComments = false);
    }
  }

  Future<void> _addComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    // UI check: block banned account from commenting
    try {
      final me = await supabase
          .from('profiles')
          .select('banned')
          .eq('id', user.id)
          .maybeSingle();
      if ((me != null) && (me['banned'] == true)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Banned users cannot comment.')),
          );
        }
        return;
      }
    } catch (_) {}
    final repo = ref.read(commentsRepositoryProvider);
    // Optimistic append
    final tempId = 'local-${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      comments = [
        ...comments,
        {
          'id': tempId,
          'user_id': user.id,
          'username': 'You',
          'avatar_url': null,
          'content': text,
          'created_at': DateTime.now(),
        },
      ];
      _commentCount = (comments.length);
    });
    _commentCtrl.clear();
    try {
      await repo.addComment(
        postId: widget.post.id,
        userId: user.id,
        content: text,
      );
      await _loadComments();
    } catch (_) {
      // Rollback optimistic on failure
      setState(() {
        comments = comments.where((c) => c['id'] != tempId).toList();
        _commentCount = comments.length;
      });
    }
  }

  Future<void> _loadCommentLikes(String commentId, String? userId) async {
    if (_loadingLikes[commentId] == true) return;
    setState(() => _loadingLikes[commentId] = true);
    try {
      final repo = ref.read(commentLikesRepositoryProvider);
      final res = await repo.getForComment(commentId, userId);
      if (!mounted) return;
      setState(() {
        _commentLikeCounts[commentId] = res.count;
        if (res.likedByMe) {
          _likedComments.add(commentId);
        } else {
          _likedComments.remove(commentId);
        }
      });
    } finally {
      if (mounted) setState(() => _loadingLikes[commentId] = false);
    }
  }

  Future<void> _toggleCommentLike(String commentId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final liked = _likedComments.contains(commentId);
    setState(() {
      if (liked) {
        _likedComments.remove(commentId);
        _commentLikeCounts[commentId] =
            (_commentLikeCounts[commentId] ?? 1) - 1;
      } else {
        _likedComments.add(commentId);
        _commentLikeCounts[commentId] =
            (_commentLikeCounts[commentId] ?? 0) + 1;
      }
    });
    final repo = ref.read(commentLikesRepositoryProvider);
    await repo.setLike(commentId: commentId, userId: user.id, like: !liked);
    // No await reload here; optimistic update is fine
  }

  Future<void> _loadReplies(String commentId) async {
    setState(() => _loadingReplies[commentId] = true);
    try {
      final repo = ref.read(commentRepliesRepositoryProvider);
      final list = await repo.fetchForComment(commentId);
      if (!mounted) return;
      setState(() {
        _repliesByComment[commentId] = list;
      });
    } finally {
      if (mounted) setState(() => _loadingReplies[commentId] = false);
    }
  }

  Future<void> _addReply(String commentId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final ctrl = _replyControllers.putIfAbsent(
      commentId,
      () => TextEditingController(),
    );
    final text = ctrl.text.trim();
    if (text.isEmpty) return;
    ctrl.clear();
    try {
      final repo = ref.read(commentRepliesRepositoryProvider);
      await repo.addReply(commentId: commentId, userId: user.id, content: text);
      await _loadReplies(commentId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Replies are not available right now')),
        );
      }
    }
  }

  Future<void> _saveEditedComment(String commentId) async {
    final text = _editCommentCtrl.text.trim();
    if (text.isEmpty) return;
    try {
      await ref
          .read(commentsRepositoryProvider)
          .updateComment(commentId: commentId, content: text);
      setState(() => _editingCommentId = null);
      await _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }
  }

  Future<void> _sharePost() async {
    final p = widget.post;
    final text = StringBuffer()
      ..writeln('Check out this post on Kyotee:')
      ..writeln(p.content.trim().isEmpty ? '(Image post)' : p.content.trim());
    if ((p.imageUrl ?? '').isNotEmpty) {
      text.writeln('\n${p.imageUrl!}');
    }
    final shareText = text.toString();
    try {
      await Share.share(shareText, subject: 'Kyotee Post');
    } catch (_) {
      // Fallback to clipboard copy
      await Clipboard.setData(ClipboardData(text: shareText));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post copied to clipboard')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final content = p.content;
    final imageUrl = p.imageUrl ?? '';
    final avatarUrl = p.avatarUrl;
    final currentUserId = supabase.auth.currentUser?.id;
    final isDev = currentUserId != null && currentUserId == devUserId;
    final isOwner = currentUserId != null && currentUserId == p.userId;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? CachedNetworkImageProvider(avatarUrl)
                      : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.username,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Debug viewed badge removed; a views counter with icon is shown in the actions row
                if (isDev || isOwner)
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete post?'),
                            content: const Text(
                              'This action cannot be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          try {
                            await supabase
                                .from('posts')
                                .delete()
                                .eq('id', p.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Post deleted')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Delete failed: $e')),
                              );
                            }
                          }
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
            if (content.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(content),
            ],
            if (imageUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: GestureDetector(
                  onTap: () => showFullScreenImage(context, imageUrl),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 150,
                      alignment: Alignment.center,
                      color: Colors.black12,
                      child: const Text('Image failed to load'),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final engage = ref.watch(engagementModeProvider);
                if (engage == EngagementMode.likes) {
                  return Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.thumb_up_alt,
                          color: myReaction == 'like' ? Colors.blue : null,
                        ),
                        onPressed: loadingReactions
                            ? null
                            : () => _toggleReaction('like'),
                      ),
                      Text('$likeCount'),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.thumb_down_alt,
                          color: myReaction == 'dislike' ? Colors.red : null,
                        ),
                        onPressed: loadingReactions
                            ? null
                            : () => _toggleReaction('dislike'),
                      ),
                      // Intentionally hide dislike count from UI; kept for algorithm only
                      const SizedBox(width: 8),
                      Icon(Icons.visibility, size: 20, color: Colors.grey),
                      const SizedBox(width: 2),
                      Text(
                        _viewsCount == null ? '…' : '${_viewsCount}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Share',
                        icon: const Icon(Icons.share),
                        onPressed: _sharePost,
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          setState(() => showComments = !showComments);
                          if (showComments && comments.isEmpty) {
                            await _loadComments();
                          }
                        },
                        icon: const Icon(Icons.comment),
                        label: Text(
                          (_commentCount ?? 0) > 0
                              ? 'Comments (${_commentCount})'
                              : 'Comments',
                        ),
                      ),
                    ],
                  );
                } else {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2.0,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12,
                            ),
                          ),
                          child: Slider(
                            value: _myRating.toDouble(),
                            min: 1,
                            max: 10,
                            divisions: 9,
                            onChanged: (v) {
                              setState(
                                () => _myRating = v.round().clamp(1, 10),
                              );
                            },
                            onChangeEnd: (v) async {
                              final val = v.round().clamp(1, 10);
                              await _saveRating(val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceVariant.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_myRating}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.visibility, size: 18, color: Colors.grey),
                      const SizedBox(width: 2),
                      Text(
                        _viewsCount == null ? '…' : '${_viewsCount}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Share',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.share),
                        onPressed: _sharePost,
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          setState(() => showComments = !showComments);
                          if (showComments && comments.isEmpty) {
                            await _loadComments();
                          }
                        },
                        icon: const Icon(Icons.comment),
                        label: Text(
                          (_commentCount ?? 0) > 0
                              ? 'Comments (${_commentCount})'
                              : 'Comments',
                        ),
                      ),
                    ],
                  );
                }
              },
            ),

            if (showComments) ...[
              const Divider(),
              if (loadingComments)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                ...comments.map((c) {
                  final a = c['avatar_url'] as String?;
                  final cid = c['id'] as String?;
                  final ownerId = c['user_id'] as String?;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: (a != null && a.isNotEmpty)
                              ? CachedNetworkImageProvider(a)
                              : null,
                          child: (a == null || a.isEmpty)
                              ? const Icon(Icons.person, size: 16)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c['username']?.toString() ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (_editingCommentId == cid) ...[
                                TextField(
                                  controller: _editCommentCtrl,
                                  maxLines: null,
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    hintText: 'Edit your comment',
                                  ),
                                ),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () => _saveEditedComment(cid!),
                                      child: const Text('Save'),
                                    ),
                                    TextButton(
                                      onPressed: () => setState(
                                        () => _editingCommentId = null,
                                      ),
                                      child: const Text('Cancel'),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                Text(c['content']?.toString() ?? ''),
                              ],
                              const SizedBox(height: 4),
                              if (cid != null)
                                Builder(
                                  builder: (context) {
                                    final count = _commentLikeCounts[cid] ?? 0;
                                    final liked = _likedComments.contains(cid);
                                    final loading = _loadingLikes[cid] == true;
                                    return Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.thumb_up,
                                            size: 18,
                                            color: liked ? Colors.blue : null,
                                          ),
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                          onPressed: loading
                                              ? null
                                              : () => _toggleCommentLike(cid),
                                        ),
                                        Text('$count'),
                                        const SizedBox(width: 12),
                                        TextButton(
                                          onPressed: () {
                                            setState(() {
                                              _showReplyComposer[cid] =
                                                  !(_showReplyComposer[cid] ??
                                                      false);
                                            });
                                          },
                                          child: const Text('Reply'),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton(
                                          onPressed: () async {
                                            await _loadReplies(cid);
                                          },
                                          child: const Text('View replies'),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              if (cid != null &&
                                  (_showReplyComposer[cid] ?? false)) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _replyControllers
                                            .putIfAbsent(
                                              cid,
                                              () => TextEditingController(),
                                            ),
                                        decoration: const InputDecoration(
                                          hintText: 'Write a reply...',
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.send),
                                      onPressed: () => _addReply(cid),
                                    ),
                                  ],
                                ),
                              ],
                              if (cid != null) ...[
                                if (_loadingReplies[cid] == true)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 4),
                                    child: SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                else ...[
                                  ...(_repliesByComment[cid] ??
                                          const <Map<String, dynamic>>[])
                                      .map((r) {
                                        final ra = r['avatar_url'] as String?;
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: 6,
                                            left: 32,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              CircleAvatar(
                                                radius: 12,
                                                backgroundImage:
                                                    (ra != null &&
                                                        ra.isNotEmpty)
                                                    ? CachedNetworkImageProvider(
                                                        ra,
                                                      )
                                                    : null,
                                                child:
                                                    (ra == null || ra.isEmpty)
                                                    ? const Icon(
                                                        Icons.person,
                                                        size: 12,
                                                      )
                                                    : null,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      r['username']
                                                              ?.toString() ??
                                                          'Unknown',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      r['content']
                                                              ?.toString() ??
                                                          '',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      })
                                      .toList(),
                                ],
                              ],
                            ],
                          ),
                        ),
                        if ((isDev ||
                                (currentUserId != null &&
                                    currentUserId == ownerId)) &&
                            cid != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit comment',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () {
                                  setState(() {
                                    _editingCommentId = cid;
                                    _editCommentCtrl.text =
                                        c['content']?.toString() ?? '';
                                  });
                                },
                              ),
                              IconButton(
                                tooltip: 'Delete comment',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Delete comment?'),
                                      content: const Text(
                                        'This action cannot be undone.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    try {
                                      await ref
                                          .read(commentsRepositoryProvider)
                                          .deleteComment(cid);
                                      await _loadComments();
                                      setState(() {
                                        _commentCount = comments.length;
                                      });
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text('Delete failed: $e'),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                }).toList(),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Add a comment...',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _addComment,
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ===================== Create Post =====================
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});
  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _content = TextEditingController();
  Uint8List? _imageBytes;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _imageBytes = bytes);
    }
  }

  Future<String?> _uploadPostImage(Uint8List bytes) async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    // Normalize to jpg for consistency across platforms
    const ext = '.jpg';
    final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';
    final objectPath = 'posts/${user.id}/$fileName';

    await supabase.storage
        .from('post_images')
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    final publicUrl = supabase.storage
        .from('post_images')
        .getPublicUrl(objectPath);
    return publicUrl;
  }

  Future<void> _createPost() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw 'You must be logged in';
      // Prevent banned users from posting (UI check; enforce via RLS too)
      try {
        final me = await supabase
            .from('profiles')
            .select('banned')
            .eq('id', user.id)
            .maybeSingle();
        if ((me != null) && (me['banned'] == true)) {
          throw 'Your account is banned from posting.';
        }
      } catch (e) {
        if (e is String) rethrow;
      }

      final text = _content.text.trim();
      if (text.isEmpty && _imageBytes == null) {
        throw 'Post must have text or an image';
      }

      String? imageUrl;
      if (_imageBytes != null) {
        imageUrl = await _uploadPostImage(_imageBytes!);
      }

      await supabase.from('posts').insert({
        'user_id': user.id,
        'content': text,
        'image_url': imageUrl,
      });

      if (!mounted) return;
      _content.clear();
      setState(() => _imageBytes = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post created')));
      // Return to the previous screen (Feed) after a successful post
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Post')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            TextField(
              controller: _content,
              decoration: const InputDecoration(
                labelText: "What's on your mind?",
                border: OutlineInputBorder(),
              ),
              maxLines: null,
            ),
            const SizedBox(height: 12),
            if (_imageBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _imageBytes!,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _imageBytes = null),
                child: const Text('Remove image'),
              ),
            ] else
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
                label: const Text('Add image'),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading
                    ? null
                    : () async {
                        FocusScope.of(context).unfocus();
                        await _createPost();
                      },
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Post'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== Profile =====================
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic>? profile;
  Uint8List? _newAvatarBytes;
  bool _loading = false;
  String? _error;
  bool _contactsGranted = false;
  static const _contactsPrefKey = 'profile_contacts_granted';
  bool _checkingIconSupport = true;
  bool _appIconSupported = false;
  bool _changingIcon = false;
  String? _currentIconName;
  bool _updatingEmail = false;

  static const _iconOptions = <_IconOption>[
    _IconOption(
      iconName: null,
      label: 'Classic',
      previewAsset: 'assets/app_icons/classic.png',
    ),
    _IconOption(
      iconName: 'NeonBlue',
      label: 'Neon Blue',
      previewAsset: 'assets/app_icons/neon_blue.png',
    ),
    _IconOption(
      iconName: 'NeonPurple',
      label: 'Neon Purple',
      previewAsset: 'assets/app_icons/neon_purple.png',
    ),
    _IconOption(
      iconName: 'NeonYellow',
      label: 'Neon Yellow',
      previewAsset: 'assets/app_icons/neon_yellow.png',
    ),
    _IconOption(
      iconName: 'NeonWhite',
      label: 'Neon White',
      previewAsset: 'assets/app_icons/neon_white.png',
    ),
    _IconOption(
      iconName: 'NeonTeal',
      label: 'Neon Teal',
      previewAsset: 'assets/app_icons/neon_teal.png',
    ),
  ];

  List<Map<String, dynamic>> friends = [];
  List<Map<String, dynamic>> friendRequests = [];
  bool _showAllPosts = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadFriends();
    _loadStoredContactsPermission();
    _loadAppIconState();
  }

  Future<void> _loadProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final data = await supabase
        .from('profiles')
        .select('username, avatar_url, email, phone')
        .eq('id', user.id)
        .maybeSingle();
    setState(() => profile = data);
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _newAvatarBytes = bytes);
      // Auto-save avatar after picking to ensure upload applies
      await _saveProfile();
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw 'Not logged in';

      String username = (profile?['username'] ?? '').toString().trim();
      String phone = (profile?['phone'] ?? '').toString().trim();
      if (username.isEmpty) throw 'Username cannot be empty';
      // Optional on profile page, but if provided enforce validity
      if (phone.isNotEmpty) {
        final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length < 10) {
          throw 'Please enter a valid phone number';
        }
      }

      String? avatarUrl = profile?['avatar_url'] as String?;

      if (_newAvatarBytes != null) {
        // Force a stable path and content-type for avatars
        final objectPath = 'profile_pictures/${user.id}.jpg';

        await supabase.storage
            .from('profile_pictures')
            .uploadBinary(
              objectPath,
              _newAvatarBytes!,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'image/jpeg',
              ),
            );

        // Append timestamp to avoid stale cached public URL after updates
        final base = supabase.storage
            .from('profile_pictures')
            .getPublicUrl(objectPath);
        final ts = DateTime.now().millisecondsSinceEpoch;
        avatarUrl = '$base?t=$ts';
      }

      await supabase
          .from('profiles')
          .update({
            'username': username,
            'avatar_url': avatarUrl,
            'phone': phone,
          })
          .eq('id', user.id);

      await _loadProfile();
      if (!mounted) return;
      setState(() => _newAvatarBytes = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await supabase.auth.signOut();
    }
  }

  Future<void> _requestAccountDeletion() async {
    final uri = _accountDeletionUri();
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open your browser. Visit $accountDeletionUrl to request deletion or email $accountDeletionEmail.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open deletion link: $e')),
      );
    }
  }

  Future<void> _requestPartialDeletion() async {
    final uri = _partialDeletionUri();
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open your browser. Visit $partialDataDeletionUrl for instructions.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open data management link: $e')),
      );
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = _privacyPolicyUri();
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open your browser. Visit $privacyPolicyUrl to review our privacy policy.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open privacy policy: $e')),
      );
    }
  }

  Future<void> _confirmAccountDeletion() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This will permanently delete your Kyotee account and all associated data. This action cannot be undone. '
          'We\'ll open the data-deletion instructions in your browser so you can submit the final request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('I understand, delete account'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _requestAccountDeletion();
    }
  }

  Future<void> _loadStoredContactsPermission() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_contactsPrefKey);
    if (stored != null && mounted) {
      setState(() => _contactsGranted = stored);
    }
  }

  Future<void> _loadAppIconState() async {
    final supported = await AppIconService.supportsAlternateIcons();
    String? current;
    if (supported) {
      current = await AppIconService.currentIconName();
    }
    if (!mounted) return;
    setState(() {
      _appIconSupported = supported;
      _currentIconName = current;
      _checkingIconSupport = false;
    });
  }

  bool _isIconSelected(_IconOption option) {
    final current = _currentIconName;
    return (current == null && option.iconName == null) ||
        (current != null && current == option.iconName);
  }

  Future<void> _changeAppIcon(_IconOption option) async {
    if (!_appIconSupported || _changingIcon) return;
    final target = option.iconName;
    if (_isIconSelected(option)) return;
    setState(() => _changingIcon = true);
    try {
      await AppIconService.setIcon(target);
      if (!mounted) return;
      setState(() => _currentIconName = target);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('App icon switched to ${option.label}.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to change icon: $e')));
    } finally {
      if (mounted) setState(() => _changingIcon = false);
    }
  }

  Widget _buildAppIconPicker(BuildContext context) {
    if (_checkingIconSupport) {
      return Row(
        children: const [
          SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Checking if your device supports alternate app icons…',
            ),
          ),
        ],
      );
    }
    if (!_appIconSupported) {
      return const Text(
        'Alternate icons are available when you run Kyotee on iOS 10.3 or later.',
        style: TextStyle(fontStyle: FontStyle.italic),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('App icon'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _iconOptions.map((option) {
            final selected = _isIconSelected(option);
            return ChoiceChip(
              label: Text(option.label),
              avatar: CircleAvatar(
                radius: 12,
                backgroundImage: AssetImage(option.previewAsset),
              ),
              selected: selected,
              onSelected: _changingIcon
                  ? null
                  : (value) {
                      if (value) _changeAppIcon(option);
                    },
            );
          }).toList(),
        ),
        if (_changingIcon)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 3),
          ),
        const SizedBox(height: 4),
        Text(
          'Pick one of the preset icons to change how Kyotee looks on your home screen.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> _requestContacts() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.macOS)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contacts not supported on this platform.'),
          ),
        );
      }
      return;
    }
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_contactsPrefKey, granted);
      if (mounted) {
        setState(() => _contactsGranted = granted);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              granted ? 'Contacts access granted' : 'Contacts access denied',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to request contacts: $e')));
    }
  }

  Future<void> _changeUsernameDialog() async {
    final controller = TextEditingController(
      text: profile?['username']?.toString() ?? '',
    );
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Username'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'New username'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      setState(() => profile!['username'] = newName);
      await _saveProfile();
    }
  }

  Future<void> _changePhoneDialog() async {
    final controller = TextEditingController(
      text: (profile?['phone'] ?? '').toString(),
    );
    final newPhone = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Phone Number'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone number'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newPhone == null) return;
    final digits = newPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number')),
      );
      return;
    }
    setState(() => profile!['phone'] = newPhone);
    await _saveProfile();
  }

  Future<void> _changeEmailDialog() async {
    final currentEmail =
        (profile?['email'] ?? supabase.auth.currentUser?.email ?? '')
            .toString();
    final emailCtrl = TextEditingController(text: currentEmail);
    final passwordCtrl = TextEditingController();
    bool obscure = true;
    String? errorText;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Change Email'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'New email address',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: obscure,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Current password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setStateDialog(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        errorText!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final nextEmail = emailCtrl.text.trim();
                    final password = passwordCtrl.text;
                    if (nextEmail.isEmpty) {
                      setStateDialog(
                        () => errorText = 'Please enter a new email address.',
                      );
                      return;
                    }
                    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!emailRegex.hasMatch(nextEmail)) {
                      setStateDialog(
                        () => errorText =
                            'Enter a valid email address (name@example.com).',
                      );
                      return;
                    }
                    if (password.isEmpty) {
                      setStateDialog(
                        () => errorText = 'Please enter your current password.',
                      );
                      return;
                    }
                    Navigator.pop(context, {
                      'email': nextEmail,
                      'password': password,
                    });
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;
    final newEmail = result['email']!;
    final password = result['password']!;
    await _updateEmail(newEmail, password);
  }

  Future<void> _updateEmail(String newEmail, String password) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final trimmedEmail = newEmail.trim();
    final currentEmail = user.email ?? '';
    if (currentEmail.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot update email because your current email is unavailable.',
            ),
          ),
        );
      }
      return;
    }
    if (trimmedEmail.toLowerCase() == currentEmail.toLowerCase()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That is already your current email.')),
        );
      }
      return;
    }

    setState(() {
      _updatingEmail = true;
      _error = null;
    });

    try {
      await supabase.auth.signInWithPassword(
        email: currentEmail,
        password: password,
      );
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _updatingEmail = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password verification failed: ${e.message}')),
        );
      }
      return;
    } catch (e) {
      if (mounted) {
        setState(() => _updatingEmail = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to verify password: $e')),
        );
      }
      return;
    }

    try {
      await supabase.auth.updateUser(UserAttributes(email: trimmedEmail));
      await supabase
          .from('profiles')
          .update({'email': trimmedEmail})
          .eq('id', user.id);
      await _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'We\'ve sent a confirmation link to $trimmedEmail. '
              'Follow it to finish updating your email.',
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update email: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not update email: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _updatingEmail = false);
      }
    }
  }

  Future<void> _loadFriends() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final f = await supabase
        .from('friends')
        .select(
          'id, requester_id, accepter_id, status, requester:profiles!friends_requester_id_fkey(username, avatar_url, email, phone), accepter:profiles!friends_accepter_id_fkey(username, avatar_url, email, phone)',
        )
        .or('requester_id.eq.${user.id},accepter_id.eq.${user.id}');
    final reqs = (f as List)
        .where(
          (fx) => fx['status'] == 'pending' && (fx['accepter_id'] == user.id),
        )
        .cast<Map<String, dynamic>>()
        .toList();
    final confirmed = (f as List)
        .where((fx) => fx['status'] == 'accepted')
        .cast<Map<String, dynamic>>()
        .toList();

    setState(() {
      friendRequests = reqs;
      friends = confirmed;
    });
  }

  int? _ageFromMetadata() {
    final u = supabase.auth.currentUser;
    final bdayStr = u?.userMetadata?['birthday'] as String?;
    if (bdayStr == null) return null;
    final bday = DateTime.tryParse(bdayStr);
    if (bday == null) return null;
    final now = DateTime.now();
    return now.year -
        bday.year -
        ((now.month < bday.month ||
                (now.month == bday.month && now.day < bday.day))
            ? 1
            : 0);
  }

  Future<void> _acceptFriendRequest(String friendId) async {
    try {
      // Enforce contacts-only for minors when accepting
      final age = _ageFromMetadata();
      if (age != null && age < 18) {
        if (kIsWeb ||
            (defaultTargetPlatform != TargetPlatform.iOS &&
                defaultTargetPlatform != TargetPlatform.android &&
                defaultTargetPlatform != TargetPlatform.macOS)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Contacts check not supported on this platform.'),
              ),
            );
          }
          return;
        }
        final req = friendRequests.firstWhere(
          (r) => r['id'] == friendId,
          orElse: () => {},
        );
        if (req.isEmpty) return;
        // The requester is the other person when current user is the accepter
        final requester = req['requester'] as Map<String, dynamic>?;
        final requesterEmail = requester?['email']
            ?.toString()
            .trim()
            .toLowerCase();
        final requesterPhone = requester?['phone']?.toString().trim();
        if (requesterEmail == null || requesterEmail.isEmpty) {
          // If no email, we will try phone below; only block if neither present
          if (requesterPhone == null || requesterPhone.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cannot verify requester via contacts.'),
                ),
              );
            }
            return;
          }
        }
        final granted = await FlutterContacts.requestPermission(readonly: true);
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Contacts permission denied')),
            );
          }
          return;
        }
        final contacts = await FlutterContacts.getContacts(
          withProperties: true,
        );
        final inContacts = contacts.any((c) {
          final emailMatch =
              (requesterEmail != null && requesterEmail.isNotEmpty)
              ? c.emails.any(
                  (e) => e.address.trim().toLowerCase() == requesterEmail,
                )
              : false;
          final phoneMatch =
              (requesterPhone != null && requesterPhone.isNotEmpty)
              ? c.phones.any((p) => _phoneDigitsMatch(p.number, requesterPhone))
              : false;
          return emailMatch || phoneMatch;
        });
        if (!inContacts) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'You can only accept requests from your contacts.',
                ),
              ),
            );
          }
          return;
        }
      }
      await supabase
          .from('friends')
          .update({'status': 'accepted'})
          .eq('id', friendId);
      await _loadFriends();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Friend request accepted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to accept request: $e')));
    }
  }

  Future<void> _rejectFriendRequest(String friendId) async {
    try {
      await supabase.from('friends').delete().eq('id', friendId);
      await _loadFriends();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Friend request rejected')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to reject request: $e')));
    }
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    List<Widget>? actions,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final content = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      content.add(children[i]);
      if (i != children.length - 1) {
        content.add(const SizedBox(height: 12));
      }
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (actions != null && actions.isNotEmpty) ...actions,
              ],
            ),
            if (content.isNotEmpty) ...[const SizedBox(height: 16), ...content],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final trailingWidget = trailing;
        final useStackedLayout =
            trailingWidget != null && constraints.maxWidth < 360;

        final textColumn = Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        );

        final rowChildren = <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(icon, size: 24),
          ),
          const SizedBox(width: 12),
          textColumn,
        ];

        if (!useStackedLayout && trailingWidget != null) {
          rowChildren.add(const SizedBox(width: 12));
          rowChildren.add(
            Flexible(
              flex: 0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 36),
                child: trailingWidget,
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rowChildren,
            ),
            if (useStackedLayout && trailingWidget != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 36),
                  child: trailingWidget,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPreferencesCard(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeModeProvider) == ThemeMode.dark;
    final engagementMode = ref.watch(engagementModeProvider);
    final isSlider = engagementMode == EngagementMode.slider;

    return _buildSection(
      context: context,
      title: 'Preferences',
      children: [
        _buildAppIconPicker(context),
        SwitchListTile.adaptive(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Dark mode'),
          value: isDarkMode,
          onChanged: (v) => ref
              .read(themeModeProvider.notifier)
              .setMode(v ? ThemeMode.dark : ThemeMode.light),
        ),
        SwitchListTile.adaptive(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Slider likes'),
          subtitle: Text(isSlider ? 'On' : 'Off'),
          value: isSlider,
          onChanged: (v) => ref
              .read(engagementModeProvider.notifier)
              .setMode(v ? EngagementMode.slider : EngagementMode.likes),
        ),
        _buildInfoRow(
          context: context,
          icon: Icons.contacts_outlined,
          title: 'Contacts access',
          subtitle: _contactsGranted ? 'Granted' : 'Not granted',
          trailing: ElevatedButton(
            onPressed: _requestContacts,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Allow access'),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileInfoCard(BuildContext context) {
    final avatarUrl = (profile?['avatar_url'] ?? '').toString();
    final hasAvatar = avatarUrl.isNotEmpty;
    final username = (profile?['username'] ?? '').toString();
    final email = (profile?['email'] ?? supabase.auth.currentUser?.email ?? '')
        .toString();
    final phone = (profile?['phone'] ?? '').toString();
    final theme = Theme.of(context);

    return _buildSection(
      context: context,
      title: 'Account',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundImage: hasAvatar
                      ? CachedNetworkImageProvider(avatarUrl)
                      : null,
                  child: hasAvatar ? null : const Icon(Icons.person, size: 48),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _pickAvatar,
                  icon: const Icon(Icons.image),
                  label: const Text('Change avatar'),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          username,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: _changeUsernameDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    context: context,
                    icon: Icons.phone,
                    title: 'Phone number',
                    subtitle: phone.isEmpty ? 'Not set' : phone,
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: _changePhoneDialog,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    context: context,
                    icon: Icons.email,
                    title: 'Email address',
                    subtitle: email.isEmpty ? 'Not set' : email,
                    trailing: _updatingEmail
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: _changeEmailDialog,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDataPrivacyCard(BuildContext context) {
    final theme = Theme.of(context);

    return _buildSection(
      context: context,
      title: 'Data & privacy',
      children: [
        Text(
          'Manage what you share with Kyotee, or request removal of specific content or your entire account.',
          style: theme.textTheme.bodyMedium,
        ),
        ElevatedButton.icon(
          onPressed: _openPrivacyPolicy,
          icon: const Icon(Icons.privacy_tip),
          label: const Text('View privacy policy'),
        ),
        ElevatedButton.icon(
          onPressed: _requestPartialDeletion,
          icon: const Icon(Icons.manage_history),
          label: const Text('Manage my data'),
        ),
        ElevatedButton.icon(
          onPressed: _confirmAccountDeletion,
          icon: const Icon(Icons.delete_forever),
          label: const Text('Delete my account'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
        ),
        Text(
          'If any links fail to open, visit $privacyPolicyUrl to review our privacy policy, '
          '$partialDataDeletionUrl for data management, or $accountDeletionUrl to delete your account. '
          'You can also email $accountDeletionEmail.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildPostsCard(BuildContext context) {
    return _buildSection(
      context: context,
      title: 'My posts',
      children: [
        FutureBuilder<List<Map<String, dynamic>>>(
          future: supabase
              .from('posts')
              .select('id, content, image_url, created_at')
              .eq('user_id', supabase.auth.currentUser!.id)
              .order('created_at', ascending: false),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            final posts = snapshot.data!;
            if (posts.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('No posts yet'),
              );
            }
            final displayedPosts = _showAllPosts
                ? posts
                : posts.take(5).toList();
            return Column(
              children: [
                ...displayedPosts.map((p) {
                  final img = (p['image_url'] ?? '').toString();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((p['content'] ?? '').toString().isNotEmpty)
                            Text(
                              p['content'] ?? '',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          if (img.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => showFullScreenImage(context, img),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: img,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(
                                    height: 150,
                                    alignment: Alignment.center,
                                    color: Colors.black12,
                                    child: const Text('Image failed to load'),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
                if (!_showAllPosts && posts.length > 5)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => setState(() => _showAllPosts = true),
                      child: const Text('Show more'),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildFriendsCard(BuildContext context) {
    return _buildSection(
      context: context,
      title: 'Friends',
      children: [
        friends.isEmpty
            ? const Text('No friends yet')
            : Column(
                children: ListTile.divideTiles(
                  context: context,
                  tiles: friends.map((f) {
                    final friendData =
                        f['requester_id'] == supabase.auth.currentUser!.id
                        ? f['accepter']
                        : f['requester'];
                    final avatar = friendData['avatar_url']?.toString();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundImage: (avatar != null && avatar.isNotEmpty)
                            ? CachedNetworkImageProvider(avatar)
                            : null,
                        child: (avatar == null || avatar.isEmpty)
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(friendData['username'] ?? 'Unknown'),
                      subtitle: const Text('Friend'),
                    );
                  }),
                ).toList(),
              ),
      ],
    );
  }

  Widget _buildFriendRequestsCard(BuildContext context) {
    return _buildSection(
      context: context,
      title: 'Friend requests',
      children: [
        friendRequests.isEmpty
            ? const Text('No pending requests')
            : Column(
                children: ListTile.divideTiles(
                  context: context,
                  tiles: friendRequests.map((f) {
                    final requester = f['requester'];
                    final avatar = requester['avatar_url']?.toString();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundImage: (avatar != null && avatar.isNotEmpty)
                            ? CachedNetworkImageProvider(avatar)
                            : null,
                        child: (avatar == null || avatar.isEmpty)
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(requester['username'] ?? 'Unknown'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _acceptFriendRequest(f['id']),
                            icon: const Icon(Icons.check, color: Colors.green),
                          ),
                          IconButton(
                            onPressed: () => _rejectFriendRequest(f['id']),
                            icon: const Icon(Icons.close, color: Colors.red),
                          ),
                        ],
                      ),
                    );
                  }),
                ).toList(),
              ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (supabase.auth.currentUser?.id == devUserId)
            IconButton(
              tooltip: 'Admin',
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DevAdminScreen()),
                );
              },
            ),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            _buildPreferencesCard(context, ref),
            _buildProfileInfoCard(context),
            _buildDataPrivacyCard(context),
            _buildPostsCard(context),
            _buildFriendsCard(context),
            _buildFriendRequestsCard(context),
          ],
        ),
      ),
    );
  }
}

class _IconOption {
  final String? iconName;
  final String label;
  final String previewAsset;

  const _IconOption({
    required this.iconName,
    required this.label,
    required this.previewAsset,
  });
}

// ===================== Dev Admin =====================
class DevAdminScreen extends ConsumerStatefulWidget {
  const DevAdminScreen({super.key});
  @override
  ConsumerState<DevAdminScreen> createState() => _DevAdminScreenState();
}

class _DevAdminScreenState extends ConsumerState<DevAdminScreen> {
  final _queryCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  final _daysCtrl = TextEditingController(text: '7');
  bool _permanent = false;

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final list = await repo.searchUsers(_queryCtrl.text);
      setState(() => _results = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleBan(Map<String, dynamic> user) async {
    final userId = user['id'] as String;
    final banned = (user['banned'] == true);
    final email = (user['email'] ?? '').toString();
    if (!banned) {
      // Ban dialog
      _daysCtrl.text = '7';
      _permanent = false;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Ban User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('Permanent'),
                  const SizedBox(width: 8),
                  Switch(
                    value: _permanent,
                    onChanged: (v) => setState(() => _permanent = v),
                  ),
                ],
              ),
              if (!_permanent) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _daysCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ban duration (days)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ban'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      try {
        DateTime? until;
        if (!_permanent) {
          final days = int.tryParse(_daysCtrl.text.trim());
          if (days != null && days > 0)
            until = DateTime.now().add(Duration(days: days));
        }
        await ref
            .read(adminRepositoryProvider)
            .banUser(userId: userId, email: email, until: until);
        setState(() => user['banned'] = true);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User banned')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Action failed: $e')));
      }
    } else {
      // Unban now
      try {
        await ref
            .read(adminRepositoryProvider)
            .unbanUser(userId: userId, email: email);
        setState(() => user['banned'] = false);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User unbanned')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Action failed: $e')));
      }
    }
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (supabase.auth.currentUser?.id != devUserId) {
      return const Scaffold(body: Center(child: Text('Unauthorized')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Tools')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _queryCtrl,
              decoration: const InputDecoration(
                labelText: 'Search by username or email',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _search,
                child: _loading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Search'),
              ),
            ),
            const Divider(height: 24),
            Expanded(
              child: _results.isEmpty
                  ? const Center(child: Text('No results'))
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final u = _results[i];
                        final avatar = u['avatar_url'] as String?;
                        final banned = u['banned'] == true;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage:
                                (avatar != null && avatar.isNotEmpty)
                                ? CachedNetworkImageProvider(avatar)
                                : null,
                            child: (avatar == null || avatar.isEmpty)
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(u['username']?.toString() ?? ''),
                          subtitle: Text(u['email']?.toString() ?? ''),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (banned)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.12),
                                    border: Border.all(
                                      color: Colors.red.withOpacity(0.6),
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Banned',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () => _toggleBan(u),
                                child: Text(banned ? 'Unban' : 'Ban'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

//---------------Search Screen------------------
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> userResults = [];
  List<Post> postResults = [];

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() {
        userResults = [];
        postResults = [];
      });
      return;
    }

    // Run both searches in parallel
    try {
      final futures = <Future>[
        // Users by username
        supabase
            .from('profiles')
            .select('id, username, avatar_url')
            .ilike('username', '%$query%')
            .neq('id', supabase.auth.currentUser!.id),
        // Posts by content
        supabase
            .from('posts')
            .select(
              'id, content, image_url, created_at, user_id, profiles(username, avatar_url, banned)',
            )
            .ilike('content', '%$query%')
            .order('created_at', ascending: false),
        // Posts by author username
        supabase
            .from('posts')
            .select(
              'id, content, image_url, created_at, user_id, profiles!inner(username, avatar_url, banned)',
            )
            .ilike('profiles.username', '%$query%')
            .order('created_at', ascending: false),
      ];

      final results = await Future.wait(futures);
      final users = (results[0] as List).cast<Map<String, dynamic>>();
      final postsByContentRaw = (results[1] as List)
          .cast<Map<String, dynamic>>();
      final postsByAuthorRaw = (results[2] as List)
          .cast<Map<String, dynamic>>();
      final postsByContent = postsByContentRaw
          .map(Post.fromMap)
          .where((p) => !p.banned);
      final postsByAuthor = postsByAuthorRaw
          .map(Post.fromMap)
          .where((p) => !p.banned);
      // Merge and de-duplicate by post id, then sort newest first
      final Map<String, Post> postsMap = {
        for (final p in [...postsByContent, ...postsByAuthor]) p.id: p,
      };
      final posts = postsMap.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) return;
      setState(() {
        userResults = users;
        postResults = posts;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        userResults = [];
        postResults = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _search,
            ),
          ),
          Expanded(
            child:
                (_searchController.text.isEmpty &&
                    userResults.isEmpty &&
                    postResults.isEmpty)
                ? const Center(child: Text('Type to search users and posts'))
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (userResults.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: Text(
                            'Users',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(8),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.85,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                          itemCount: userResults.length,
                          itemBuilder: (context, index) {
                            final user = userResults[index];
                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PublicProfileScreen(userId: user['id']),
                                ),
                              ),
                              child: Card(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircleAvatar(
                                      radius: 36,
                                      backgroundImage:
                                          user['avatar_url'] != null
                                          ? CachedNetworkImageProvider(
                                              user['avatar_url'],
                                            )
                                          : null,
                                      child: user['avatar_url'] == null
                                          ? const Icon(Icons.person, size: 36)
                                          : null,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      user['username'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (postResults.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: Text(
                            'Posts',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 12),
                          itemCount: postResults.length,
                          itemBuilder: (context, index) =>
                              PostCard(post: postResults[index]),
                        ),
                      ],
                      if (userResults.isEmpty &&
                          postResults.isEmpty &&
                          _searchController.text.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: Text('No results')),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

//------------------Public Profiles---------------------
class PublicProfileScreen extends StatefulWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  Map<String, dynamic>? profile;
  List<Map<String, dynamic>> posts = [];
  bool requestSent = false;

  int? _currentUserAge() {
    final u = supabase.auth.currentUser;
    final bdayStr = u?.userMetadata?['birthday'] as String?;
    if (bdayStr == null) return null;
    final bday = DateTime.tryParse(bdayStr);
    if (bday == null) return null;
    final now = DateTime.now();
    final age =
        now.year -
        bday.year -
        ((now.month < bday.month ||
                (now.month == bday.month && now.day < bday.day))
            ? 1
            : 0);
    return age;
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkFriendRequest();
  }

  Future<void> _loadProfile() async {
    final data = await supabase
        .from('profiles')
        .select('username, avatar_url, email, phone')
        .eq('id', widget.userId)
        .maybeSingle();
    final userPosts = await supabase
        .from('posts')
        .select('id, content, image_url, created_at')
        .eq('user_id', widget.userId)
        .order('created_at', ascending: false);

    setState(() {
      profile = data;
      posts = (userPosts as List).cast<Map<String, dynamic>>();
    });
  }

  Future<void> _checkFriendRequest() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;
    try {
      // Check for any existing relationship (pending or accepted) between the two users
      final existing = await supabase
          .from('friends')
          .select('id, status')
          .or(
            'and(requester_id.eq.${currentUser.id},accepter_id.eq.${widget.userId}),and(requester_id.eq.${widget.userId},accepter_id.eq.${currentUser.id})',
          )
          .inFilter('status', ['pending', 'accepted'])
          .limit(1);
      setState(() {
        requestSent = (existing as List).isNotEmpty;
      });
    } catch (e) {
      // Surface errors in debug and keep button enabled to let user try
      // ignore: avoid_print
      print('checkFriendRequest error: $e');
    }
  }

  Future<void> _sendFriendRequest() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;
    try {
      await supabase.from('friends').insert({
        'requester_id': currentUser.id,
        'accepter_id': widget.userId,
        'status': 'pending',
      });
      setState(() => requestSent = true);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Friend request sent')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send request: $e')));
    }
  }

  Future<void> _sendFriendRequestFromContacts() async {
    final targetEmail = profile?['email']?.toString().trim().toLowerCase();
    final targetPhone = profile?['phone']?.toString().trim();
    if ((targetEmail == null || targetEmail.isEmpty) &&
        (targetPhone == null || targetPhone.isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This user has no email or phone to match.'),
        ),
      );
      return;
    }

    try {
      if (kIsWeb ||
          (defaultTargetPlatform != TargetPlatform.iOS &&
              defaultTargetPlatform != TargetPlatform.android &&
              defaultTargetPlatform != TargetPlatform.macOS)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contacts not supported on this platform.'),
          ),
        );
        return;
      }
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacts permission denied')),
        );
        return;
      }

      final contacts = await FlutterContacts.getContacts(withProperties: true);
      final inContacts = contacts.any((c) {
        final emailMatch = (targetEmail != null && targetEmail.isNotEmpty)
            ? c.emails.any(
                (e) => (e.address.trim().toLowerCase()) == targetEmail,
              )
            : false;
        final phoneMatch = (targetPhone != null && targetPhone.isNotEmpty)
            ? c.phones.any((p) => _phoneDigitsMatch(p.number, targetPhone))
            : false;
        return emailMatch || phoneMatch;
      });

      if (!inContacts) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found in your contacts')),
        );
        return;
      }

      await _sendFriendRequest();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Contacts check failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (profile == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: Text(profile!['username'])),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundImage: profile!['avatar_url'] != null
                  ? CachedNetworkImageProvider(profile!['avatar_url'])
                  : null,
              child: profile!['avatar_url'] == null
                  ? const Icon(Icons.person, size: 48)
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              profile!['username'],
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final age = _currentUserAge();
                final canFriendAnyone = age == null || age >= 18;
                return ElevatedButton(
                  onPressed: requestSent
                      ? null
                      : () async {
                          if (canFriendAnyone) {
                            await _sendFriendRequest();
                          } else {
                            await _sendFriendRequestFromContacts();
                          }
                        },
                  child: Text(
                    requestSent
                        ? 'Request Sent'
                        : (canFriendAnyone
                              ? 'Add Friend'
                              : 'Add from contacts'),
                  ),
                );
              },
            ),
            const Divider(height: 32),
            Text('Posts', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...posts.map((p) {
              final img = (p['image_url'] ?? '').toString();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((p['content'] ?? '').toString().isNotEmpty)
                        Text(p['content'] ?? ''),
                      if (img.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: GestureDetector(
                            onTap: () => showFullScreenImage(context, img),
                            child: CachedNetworkImage(
                              imageUrl: img,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                height: 150,
                                alignment: Alignment.center,
                                color: Colors.black12,
                                child: const Text('Image failed to load'),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

// ===================== Simple Chat Icon =====================
class SimpleChatIcon extends StatelessWidget {
  const SimpleChatIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? Colors.black;
    return CustomPaint(
      size: const Size(24, 24),
      painter: _FilledChatBubblePainter(color),
    );
  }
}

class _FilledChatBubblePainter extends CustomPainter {
  final Color color;
  _FilledChatBubblePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    // Main oval
    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 0.8);
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.width * 0.4),
    );
    canvas.drawRRect(rrect, paint);

    // Stem
    final path = Path();
    path.moveTo(size.width * 0.35, size.height * 0.8);
    path.lineTo(size.width * 0.45, size.height);
    path.lineTo(size.width * 0.55, size.height * 0.8);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
