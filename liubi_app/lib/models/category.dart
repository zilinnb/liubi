class Category {
  final int id;
  final String name;
  final String icon;
  final String cover;
  final String description;
  final String color;
  final int sortOrder;
  final int postCount;
  final int status;
  final int publishRestriction;

  Category({
    required this.id,
    this.name = '',
    this.icon = '',
    this.cover = '',
    this.description = '',
    this.color = '',
    this.sortOrder = 0,
    this.postCount = 0,
    this.status = 1,
    this.publishRestriction = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      icon: json['icon'] ?? '',
      cover: json['cover'] ?? '',
      description: json['description'] ?? '',
      color: json['color'] ?? '',
      sortOrder: json['sort_order'] ?? 0,
      postCount: json['post_count'] ?? 0,
      status: json['status'] ?? 1,
      publishRestriction: json['publish_restriction'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'cover': cover,
      'description': description,
      'color': color,
      'sort_order': sortOrder,
      'post_count': postCount,
      'status': status,
      'publish_restriction': publishRestriction,
    };
  }
}
