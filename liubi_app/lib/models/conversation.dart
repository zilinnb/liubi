import 'user.dart';

class Conversation {
  final int id;
  final int type;
  final String name;
  final String avatar;
  final String groupCode;
  final int createdBy;
  int unreadCount;
  final String lastMessage;
  final int? lastMessageType;
  final String lastTime;
  final String updatedAt;
  final List<String> memberAvatars;
  final List<String> memberNames;
  final List<int> memberIds;
  final int memberCount;
  final int otherUserId;
  final LevelInfo? levelInfo;
  bool isPinned;

  Conversation({
    required this.id,
    this.type = 1,
    this.name = '',
    this.avatar = '',
    this.groupCode = '',
    this.createdBy = 0,
    this.unreadCount = 0,
    this.lastMessage = '',
    this.lastMessageType,
    this.lastTime = '',
    this.updatedAt = '',
    this.memberAvatars = const [],
    this.memberNames = const [],
    this.memberIds = const [],
    this.memberCount = 0,
    this.otherUserId = 0,
    this.levelInfo,
    this.isPinned = false,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    List<String> avatars = [];
    final rawAvatars = json['member_avatars'];
    if (rawAvatars is List) {
      avatars = rawAvatars.map((e) => e.toString()).toList();
    }

    List<String> names = [];
    final rawNames = json['member_names'];
    if (rawNames is List) {
      names = rawNames.map((e) => e.toString()).toList();
    }

    List<int> ids = [];
    final rawIds = json['member_ids'];
    if (rawIds is List) {
      ids = rawIds.map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0).toList();
    }

    return Conversation(
      id: json['id'] ?? 0,
      type: json['type'] ?? 1,
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '',
      groupCode: json['group_code'] ?? '',
      createdBy: json['created_by'] ?? 0,
      unreadCount: json['unread_count'] ?? 0,
      lastMessage: json['last_message'] ?? '',
      lastMessageType: json['last_message_type'] is int ? json['last_message_type'] : null,
      lastTime: json['last_time'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      memberAvatars: avatars,
      memberNames: names,
      memberIds: ids,
      memberCount: json['member_count'] ?? 0,
      otherUserId: json['other_user_id'] ?? 0,
      levelInfo: json['level_info'] != null
          ? LevelInfo.fromJson(json['level_info'] as Map<String, dynamic>)
          : null,
      isPinned: json['is_pinned'] == 1 || json['is_pinned'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'avatar': avatar,
      'group_code': groupCode,
      'created_by': createdBy,
      'unread_count': unreadCount,
      'last_message': lastMessage,
      'last_message_type': lastMessageType,
      'last_time': lastTime,
      'updated_at': updatedAt,
      'member_avatars': memberAvatars,
      'member_names': memberNames,
      'member_ids': memberIds,
      'member_count': memberCount,
      'other_user_id': otherUserId,
      'is_pinned': isPinned ? 1 : 0,
    };
  }
}
