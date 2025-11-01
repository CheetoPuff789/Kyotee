import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:realtime_client/realtime_client.dart';

import '../../models/post.dart';
import 'posts_repository.dart';
import 'reactions_repository.dart';
import 'comments_repository.dart';
import 'views_repository.dart';
import '../admin/admin_repository.dart';
import 'comment_engagement_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final postsRepositoryProvider = Provider<PostsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return PostsRepository(client);
});

final reactionsRepositoryProvider = Provider<ReactionsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ReactionsRepository(client);
});

final commentsRepositoryProvider = Provider<CommentsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return CommentsRepository(client);
});

final viewsRepositoryProvider = Provider<ViewsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ViewsRepository(client);
});

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AdminRepository(client);
});

final commentLikesRepositoryProvider = Provider<CommentLikesRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return CommentLikesRepository(client);
});

final commentRepliesRepositoryProvider = Provider<CommentRepliesRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return CommentRepliesRepository(client);
});

final postsProvider = FutureProvider<List<Post>>((ref) async {
  final repo = ref.watch(postsRepositoryProvider);
  return repo.fetchLatest();
});

// Realtime streams
final postsStreamProvider = StreamProvider<List<Post>>((ref) async* {
  final client = ref.watch(supabaseClientProvider);
  final repo = ref.watch(postsRepositoryProvider);

  final controller = StreamController<List<Post>>();
  Future<void> load() async {
    try {
      final list = await repo.fetchLatest();
      if (!controller.isClosed) controller.add(list);
    } catch (e) {
      if (!controller.isClosed) controller.addError(e);
    }
  }

  await load();

  final channel = client
      .channel('public:posts-feed')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'posts',
        callback: (_) => load(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'posts',
        callback: (_) => load(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'posts',
        callback: (_) => load(),
      )
      .subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
    controller.close();
  });

  yield* controller.stream;
});

final recommendedPostsStreamProvider = StreamProvider<List<Post>>((ref) async* {
  final client = ref.watch(supabaseClientProvider);
  final repo = ref.watch(postsRepositoryProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) {
    // fallback to latest if not logged in
    yield* ref.watch(postsStreamProvider.stream);
    return;
  }

  final controller = StreamController<List<Post>>();
  Future<void> load() async {
    try {
      final list = await repo.fetchRecommended(userId);
      if (!controller.isClosed) controller.add(list);
    } catch (e) {
      if (!controller.isClosed) controller.addError(e);
    }
  }

  await load();

  final postsChannel = client
      .channel('public:posts-reco')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'posts',
        callback: (_) => load(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'posts',
        callback: (_) => load(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'posts',
        callback: (_) => load(),
      )
      .subscribe();

  final reactionsChannel = client
      .channel('public:reactions-reco:${userId.substring(0, 6)}')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'post_reactions',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (_) => load(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'post_reactions',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (_) => load(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'post_reactions',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (_) => load(),
      )
      .subscribe();

  final viewsChannel = client
      .channel('public:views-reco:${userId.substring(0, 6)}')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'post_views',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (_) => load(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'post_views',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (_) => load(),
      )
      .subscribe();

  ref.onDispose(() {
    client.removeChannel(postsChannel);
    client.removeChannel(reactionsChannel);
    client.removeChannel(viewsChannel);
    controller.close();
  });

  yield* controller.stream;
});

enum FeedMode { latest, recommended }

final feedModeProvider = StateProvider<FeedMode>((ref) => FeedMode.latest);
