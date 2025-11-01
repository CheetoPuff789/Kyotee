class Post {
  final String id;
  final String userId;
  final String content;
  final String? imageUrl;
  final DateTime createdAt;
  final String username;
  final String? avatarUrl;
  final bool banned;

  const Post({
    required this.id,
    required this.userId,
    required this.content,
    required this.imageUrl,
    required this.createdAt,
    required this.username,
    required this.avatarUrl,
    required this.banned,
  });

  factory Post.fromMap(Map<String, dynamic> map) {
    final profiles = map['profiles'] as Map<String, dynamic>?;
    return Post(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      content: (map['content'] ?? '').toString(),
      imageUrl: (map['image_url'] as String?)?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      username: (profiles != null ? profiles['username'] : null)?.toString() ?? 'Unknown',
      avatarUrl: (profiles != null ? profiles['avatar_url'] : null) as String?,
      banned: (profiles != null ? (profiles['banned'] == true) : false),
    );
  }
}
