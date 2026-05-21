import 'user.dart';

class Comment {
  final int id;
  final int postId;
  final int userId;
  final int parentId;
  final int replyToUserId;
  final String replyToNickname;
  final String content;
  final String imageUrl;
  final String voiceUrl;
  final int voiceDuration;
  int likesCount;
  final int status;
  final String location;
  final int isPinned;
  bool isLiked;
  final String nickname;
  final String avatar;
  final LevelInfo? levelInfo;
  final List<Comment> subComments;
  final String createdAt;

  Comment({
    required this.id,
    this.postId = 0,
    this.userId = 0,
    this.parentId = 0,
    this.replyToUserId = 0,
    this.replyToNickname = '',
    this.content = '',
    this.imageUrl = '',
    this.voiceUrl = '',
    this.voiceDuration = 0,
    this.likesCount = 0,
    this.status = 1,
    this.location = '',
    this.isPinned = 0,
    this.isLiked = false,
    this.nickname = '',
    this.avatar = '',
    this.levelInfo,
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
      replyToUserId: json['reply_to_user_id'] ?? 0,
      replyToNickname: json['reply_to_nickname'] ?? '',
      content: json['content'] ?? '',
      imageUrl: json['image_url'] ?? '',
      voiceUrl: json['voice_url'] ?? '',
      voiceDuration: json['voice_duration'] ?? 0,
      likesCount: json['likes_count'] ?? 0,
      status: json['status'] ?? 1,
      location: json['location'] ?? '',
      isPinned: json['is_pinned'] ?? 0,
      isLiked: json['isLiked'] ?? json['is_liked'] ?? false,
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'] ?? '',
      levelInfo: json['level_info'] != null
          ? LevelInfo.fromJson(json['level_info'] as Map<String, dynamic>)
          : null,
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
      'reply_to_user_id': replyToUserId,
      'reply_to_nickname': replyToNickname,
      'content': content,
      'image_url': imageUrl,
      'voice_url': voiceUrl,
      'voice_duration': voiceDuration,
      'likes_count': likesCount,
      'status': status,
      'location': location,
      'is_pinned': isPinned,
      'isLiked': isLiked,
      'nickname': nickname,
      'avatar': avatar,
      'level_info': levelInfo?.toJson(),
      'subComments': subComments.map((e) => e.toJson()).toList(),
      'created_at': createdAt,
    };
  }
}
