class ContentBlock {
  final String type;
  final String content;
  final List<Map<String, dynamic>> images;
  final String layout;
  final String url;
  final int duration;

  ContentBlock({
    this.type = '',
    this.content = '',
    this.images = const [],
    this.layout = '',
    this.url = '',
    this.duration = 0,
  });

  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'];
    List<Map<String, dynamic>> parsedImages = [];
    if (rawImages is List) {
      parsedImages = rawImages.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return ContentBlock(
      type: json['type'] ?? '',
      content: json['content'] ?? '',
      images: parsedImages,
      layout: json['layout'] ?? '',
      url: json['url'] ?? '',
      duration: json['duration'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'content': content,
      'images': images,
      'layout': layout,
      'url': url,
      'duration': duration,
    };
  }
}

class PostImage {
  final String url;
  final String mediaType;
  final String videoUrl;
  final double ratio;

  PostImage({
    this.url = '',
    this.mediaType = 'image',
    this.videoUrl = '',
    this.ratio = 1.2,
  });

  factory PostImage.fromJson(Map<String, dynamic> json) {
    return PostImage(
      url: json['url'] ?? '',
      mediaType: json['type'] ?? json['media_type'] ?? 'image',
      videoUrl: json['video_url'] ?? json['videoUrl'] ?? '',
      ratio: (json['ratio'] ?? 1.2) is int
          ? (json['ratio'] as int).toDouble()
          : (json['ratio'] ?? 1.2) as double,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'type': mediaType,
      'video_url': videoUrl,
      'ratio': ratio,
    };
  }
}

class Post {
  final int id;
  final int userId;
  final String title;
  final String content;
  final int categoryId;
  final String categoryName;
  final int postType;
  final String voiceUrl;
  final int voiceDuration;
  final int textTemplate;
  final String link;
  final List<ContentBlock> contentBlocks;
  final List<PostImage> images;
  final int likesCount;
  final int collectsCount;
  final int commentsCount;
  final int viewsCount;
  final int sharesCount;
  final int status;
  bool isLiked;
  bool isCollected;
  final int isPinned;
  final int isPrivate;
  final String location;
  final String nickname;
  final String username;
  final String avatar;
  final String createdAt;

  Post({
    required this.id,
    this.userId = 0,
    this.title = '',
    this.content = '',
    this.categoryId = 0,
    this.categoryName = '',
    this.postType = 3,
    this.voiceUrl = '',
    this.voiceDuration = 0,
    this.textTemplate = 0,
    this.link = '',
    this.contentBlocks = const [],
    this.images = const [],
    this.likesCount = 0,
    this.collectsCount = 0,
    this.commentsCount = 0,
    this.viewsCount = 0,
    this.sharesCount = 0,
    this.status = 1,
    this.isLiked = false,
    this.isCollected = false,
    this.isPinned = 0,
    this.isPrivate = 0,
    this.location = '',
    this.nickname = '',
    this.username = '',
    this.avatar = '',
    this.createdAt = '',
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    List<ContentBlock> blocks = [];
    final rawBlocks = json['content_blocks'];
    if (rawBlocks is List) {
      blocks = rawBlocks.map((e) => ContentBlock.fromJson(e as Map<String, dynamic>)).toList();
    }

    List<PostImage> imgs = [];
    final rawImgs = json['images'];
    if (rawImgs is List) {
      imgs = rawImgs.map((e) => PostImage.fromJson(e as Map<String, dynamic>)).toList();
    }

    return Post(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      categoryId: json['category_id'] ?? 0,
      categoryName: json['category_name'] ?? '',
      postType: json['post_type'] ?? 3,
      voiceUrl: json['voice_url'] ?? '',
      voiceDuration: json['voice_duration'] ?? 0,
      textTemplate: json['text_template'] ?? 0,
      link: json['link'] ?? '',
      contentBlocks: blocks,
      images: imgs,
      likesCount: json['likes_count'] ?? 0,
      collectsCount: json['collects_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      viewsCount: json['views_count'] ?? 0,
      sharesCount: json['shares_count'] ?? 0,
      status: json['status'] ?? 1,
      isLiked: json['isLiked'] ?? false,
      isCollected: json['isCollected'] ?? false,
      isPinned: json['is_pinned'] ?? 0,
      isPrivate: json['is_private'] ?? json['isPrivate'] ?? 0,
      location: json['location'] ?? '',
      nickname: json['nickname'] ?? '',
      username: json['username'] ?? '',
      avatar: json['avatar'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'content': content,
      'category_id': categoryId,
      'category_name': categoryName,
      'post_type': postType,
      'voice_url': voiceUrl,
      'voice_duration': voiceDuration,
      'text_template': textTemplate,
      'link': link,
      'content_blocks': contentBlocks.map((e) => e.toJson()).toList(),
      'images': images.map((e) => e.toJson()).toList(),
      'likes_count': likesCount,
      'collects_count': collectsCount,
      'comments_count': commentsCount,
      'views_count': viewsCount,
      'shares_count': sharesCount,
      'status': status,
      'isLiked': isLiked,
      'isCollected': isCollected,
      'is_pinned': isPinned,
      'is_private': isPrivate,
      'location': location,
      'nickname': nickname,
      'username': username,
      'avatar': avatar,
      'created_at': createdAt,
    };
  }

  Post copyWith({
    int? id,
    int? userId,
    String? title,
    String? content,
    int? categoryId,
    String? categoryName,
    int? postType,
    String? voiceUrl,
    int? voiceDuration,
    int? textTemplate,
    String? link,
    List<ContentBlock>? contentBlocks,
    List<PostImage>? images,
    int? likesCount,
    int? collectsCount,
    int? commentsCount,
    int? viewsCount,
    int? sharesCount,
    int? status,
    bool? isLiked,
    bool? isCollected,
    int? isPinned,
    int? isPrivate,
    String? location,
    String? nickname,
    String? username,
    String? avatar,
    String? createdAt,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      postType: postType ?? this.postType,
      voiceUrl: voiceUrl ?? this.voiceUrl,
      voiceDuration: voiceDuration ?? this.voiceDuration,
      textTemplate: textTemplate ?? this.textTemplate,
      link: link ?? this.link,
      contentBlocks: contentBlocks ?? this.contentBlocks,
      images: images ?? this.images,
      likesCount: likesCount ?? this.likesCount,
      collectsCount: collectsCount ?? this.collectsCount,
      commentsCount: commentsCount ?? this.commentsCount,
      viewsCount: viewsCount ?? this.viewsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      status: status ?? this.status,
      isLiked: isLiked ?? this.isLiked,
      isCollected: isCollected ?? this.isCollected,
      isPinned: isPinned ?? this.isPinned,
      isPrivate: isPrivate ?? this.isPrivate,
      location: location ?? this.location,
      nickname: nickname ?? this.nickname,
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
