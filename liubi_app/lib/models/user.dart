class User {
  final int id;
  final String username;
  final String password;
  final String nickname;
  final String avatar;
  final String bgImage;
  final String email;
  final String bio;
  final int gender;
  final String birthday;
  final int role;
  final int fansCount;
  final int followCount;
  final int likeCount;
  final int collectCount;
  final int status;
  final String location;
  final String phone;
  final int privacyFollows;
  final int privacyFans;
  final int privacyLikes;
  final int privacyActivities;
  final String createdAt;
  final String updatedAt;

  User({
    required this.id,
    this.username = '',
    this.password = '',
    this.nickname = '',
    this.avatar = '',
    this.bgImage = '',
    this.email = '',
    this.bio = '',
    this.gender = 0,
    this.birthday = '',
    this.role = 0,
    this.fansCount = 0,
    this.followCount = 0,
    this.likeCount = 0,
    this.collectCount = 0,
    this.status = 1,
    this.location = '',
    this.phone = '',
    this.privacyFollows = 0,
    this.privacyFans = 0,
    this.privacyLikes = 0,
    this.privacyActivities = 0,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'] ?? '',
      bgImage: json['bg_image'] ?? '',
      email: json['email'] ?? '',
      bio: json['bio'] ?? '',
      gender: json['gender'] ?? 0,
      birthday: json['birthday'] ?? '',
      role: json['role'] ?? 0,
      fansCount: json['fans_count'] ?? 0,
      followCount: json['follow_count'] ?? 0,
      likeCount: json['like_count'] ?? 0,
      collectCount: json['collect_count'] ?? 0,
      status: json['status'] ?? 1,
      location: json['location'] ?? '',
      phone: json['phone'] ?? '',
      privacyFollows: json['privacy_follows'] ?? 0,
      privacyFans: json['privacy_fans'] ?? 0,
      privacyLikes: json['privacy_likes'] ?? 0,
      privacyActivities: json['privacy_activities'] ?? 0,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'nickname': nickname,
      'avatar': avatar,
      'bg_image': bgImage,
      'email': email,
      'bio': bio,
      'gender': gender,
      'birthday': birthday,
      'role': role,
      'fans_count': fansCount,
      'follow_count': followCount,
      'like_count': likeCount,
      'collect_count': collectCount,
      'status': status,
      'location': location,
      'phone': phone,
      'privacy_follows': privacyFollows,
      'privacy_fans': privacyFans,
      'privacy_likes': privacyLikes,
      'privacy_activities': privacyActivities,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  User copyWith({
    int? id,
    String? username,
    String? password,
    String? nickname,
    String? avatar,
    String? bgImage,
    String? email,
    String? bio,
    int? gender,
    String? birthday,
    int? role,
    int? fansCount,
    int? followCount,
    int? likeCount,
    int? collectCount,
    int? status,
    String? location,
    String? phone,
    int? privacyFollows,
    int? privacyFans,
    int? privacyLikes,
    int? privacyActivities,
    String? createdAt,
    String? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      bgImage: bgImage ?? this.bgImage,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      role: role ?? this.role,
      fansCount: fansCount ?? this.fansCount,
      followCount: followCount ?? this.followCount,
      likeCount: likeCount ?? this.likeCount,
      collectCount: collectCount ?? this.collectCount,
      status: status ?? this.status,
      location: location ?? this.location,
      phone: phone ?? this.phone,
      privacyFollows: privacyFollows ?? this.privacyFollows,
      privacyFans: privacyFans ?? this.privacyFans,
      privacyLikes: privacyLikes ?? this.privacyLikes,
      privacyActivities: privacyActivities ?? this.privacyActivities,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
