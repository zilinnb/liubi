class Comment {
  final int id;
  final int postId;
  final int userId;
  final int parentId;
  final String content;
  final String imageUrl;
  int likesCount;
  final int status;
  final String location;
  final int isPinned;
  bool isLiked;
  final String nickname;
  final String avatar;
  final List<Comment> subComments;
  final String createdAt;

  Comment({
    required this.id,
    this.postId = 0,
    this.userId = 0,
    this.parentId = 0,
    this.content = '',
    this.imageUrl = '',
    this.likesCount = 0,
    this.status = 1,
    this.location = '',
    this.isPinned = 0,
    this.isLiked = false,
    this.nickname = '',
    this.avatar = '',
    this.subComments = const [],
    this.createdAt = '',
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    List<Comment> subs = [];
    final rawSubs = json['subComments'] ?? json['sub_comments'];
    if (rawSubs is List) {
      subs = rawSubs.map((e) => Comment.fromJson(e as Map<String, dynamic>)).toList();
    }

    return Comment(
      id: json['id'] ?? 0,
      postId: json['post_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      parentId: json['parent_id'] ?? 0,
      content: json['content'] ?? '',
      imageUrl: json['image_url'] ?? '',
      likesCount: json['likes_count'] ?? 0,
      status: json['status'] ?? 1,
      location: json['location'] ?? '',
      isPinned: json['is_pinned'] ?? 0,
      isLiked: json['isLiked'] ?? json['is_liked'] ?? false,
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'] ?? '',
      subComments: subs,
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'user_id': userId,
      'parent_id': parentId,
      'content': content,
      'image_url': imageUrl,
      'likes_count': likesCount,
      'status': status,
      'location': location,
      'is_pinned': isPinned,
      'isLiked': isLiked,
      'nickname': nickname,
      'avatar': avatar,
      'subComments': subComments.map((e) => e.toJson()).toList(),
      'created_at': createdAt,
    };
  }
}
