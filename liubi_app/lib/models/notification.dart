class UnreadNotification {
  final int likeCount;
  final int commentCount;
  final int followCount;

  UnreadNotification({
    this.likeCount = 0,
    this.commentCount = 0,
    this.followCount = 0,
  });

  factory UnreadNotification.fromJson(Map<String, dynamic> json) {
    return UnreadNotification(
      likeCount: json['like_count'] ?? 0,
      commentCount: json['comment_count'] ?? 0,
      followCount: json['follow_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'like_count': likeCount,
      'comment_count': commentCount,
      'follow_count': followCount,
    };
  }

  int get total => likeCount + commentCount + followCount;
}
