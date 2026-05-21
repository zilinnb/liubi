import 'package:flutter/foundation.dart';
import '../models/post.dart';
import '../models/category.dart' as cat_model;
import '../models/comment.dart';
import '../services/api_service.dart';

class PostProvider with ChangeNotifier {
  List<Post> posts = [];
  List<Post> followingPosts = [];
  List<cat_model.Category> categories = [];
  bool loading = false;
  bool noMore = false;
  bool followingLoading = false;
  bool followingNoMore = false;
  int _page = 1;
  int _followingPage = 1;
  int total = 0;

  Map<int, List<Post>> categoryPosts = {};
  Map<int, bool> categoryLoading = {};
  Map<int, bool> categoryNoMore = {};
  Map<int, int> _categoryPage = {};

  int get page => _page;
  set page(int v) {
    _page = v;
  }

  Future<void> fetchCategories() async {
    try {
      final res = await ApiService().get('/categories');
      if (res['code'] == 200) {
        final list = res['data'] as List;
        categories = list.map((e) => cat_model.Category.fromJson(e as Map<String, dynamic>)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> fetchPosts({bool refresh = false, bool following = false, String? sort}) async {
    if (following) {
      if (refresh) {
        _followingPage = 1;
        followingNoMore = false;
      }
      if (followingLoading) return;
      followingLoading = true;
      notifyListeners();

      try {
        final queryParams = <String, dynamic>{
          'page': _followingPage,
          'pageSize': 20,
          'following': '1',
        };
        if (sort != null && sort != 'latest') queryParams['sort'] = sort;
        final res = await ApiService().get('/posts', queryParameters: queryParams);
        if (res['code'] == 200) {
          final data = res['data'] as Map<String, dynamic>;
          final list = data['list'] as List;
          final newPosts = list.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
          if (refresh) {
            followingPosts = newPosts;
          } else {
            followingPosts.addAll(newPosts);
          }
          final t = data['total'] as int? ?? 0;
          followingNoMore = followingPosts.length >= t;
          if (!followingNoMore) _followingPage++;
        }
      } catch (_) {}

      followingLoading = false;
      notifyListeners();
      return;
    }

    if (refresh) {
      _page = 1;
      noMore = false;
    }
    if (loading) return;
    loading = true;
    notifyListeners();

    try {
      final queryParams = <String, dynamic>{
        'page': _page,
        'pageSize': 20,
      };
      if (sort != null && sort != 'latest') queryParams['sort'] = sort;
      final res = await ApiService().get('/posts', queryParameters: queryParams);
      if (res['code'] == 200) {
        final data = res['data'] as Map<String, dynamic>;
        final list = data['list'] as List;
        final newPosts = list.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
        if (refresh) {
          posts = newPosts;
        } else {
          posts.addAll(newPosts);
        }
        total = data['total'] as int? ?? 0;
        noMore = posts.length >= total;
        if (!noMore) _page++;
      }
    } catch (_) {}

    loading = false;
    notifyListeners();
  }

  void setFeedType(String type) {
    fetchPosts(refresh: true);
  }

  Future<void> fetchCategoryPosts(int categoryId, {bool refresh = false, String? sort}) async {
    if (refresh) {
      _categoryPage[categoryId] = 1;
      categoryNoMore[categoryId] = false;
    }
    if (categoryLoading[categoryId] == true) return;
    categoryLoading[categoryId] = true;
    notifyListeners();

    final pg = _categoryPage[categoryId] ?? 1;
    try {
      final queryParams = <String, dynamic>{
        'page': pg,
        'pageSize': 20,
      };
      if (sort != null && sort != 'latest') {
        queryParams['sort'] = sort;
      }
      final res = await ApiService().get('/categories/$categoryId/posts', queryParameters: queryParams);
      if (res['code'] == 200) {
        final data = res['data'] as Map<String, dynamic>;
        final list = data['list'] as List;
        final newPosts = list.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
        if (refresh) {
          categoryPosts[categoryId] = newPosts;
        } else {
          final existing = categoryPosts[categoryId] ?? [];
          categoryPosts[categoryId] = [...existing, ...newPosts];
        }
        final t = data['total'] as int? ?? 0;
        categoryNoMore[categoryId] = (categoryPosts[categoryId]?.length ?? 0) >= t;
        if (!(categoryNoMore[categoryId] ?? false)) {
          _categoryPage[categoryId] = pg + 1;
        }
      }
    } catch (_) {
      categoryPosts.putIfAbsent(categoryId, () => []);
    }

    categoryLoading[categoryId] = false;
    notifyListeners();
  }

  Future<void> loadMoreCategoryPosts(int categoryId) async {
    await fetchCategoryPosts(categoryId);
  }

  Future<Map<String, dynamic>> fetchPostById(int id) async {
    try {
      final res = await ApiService().get('/posts/$id');
      if (res['code'] == 200) {
        return {'code': 200, 'post': Post.fromJson(res['data'] as Map<String, dynamic>)};
      }
      return {'code': res['code'], 'msg': res['msg'] ?? '', 'data': res['data']};
    } catch (e) {
      debugPrint('[PostProvider] fetchPostById error: $e');
    }
    return {'code': 500, 'msg': '网络错误'};
  }

  Future<Map<String, dynamic>> createPost(Map<String, dynamic> data) async {
    return await ApiService().post('/posts', data: data);
  }

  Future<Map<String, dynamic>> updatePost(int id, Map<String, dynamic> data) async {
    return await ApiService().put('/posts/$id', data: data);
  }

  Future<Map<String, dynamic>> toggleLike(int postId) async {
    final res = await ApiService().post('/posts/$postId/like');
    if (res['code'] == 200) {
      final liked = res['data']?['liked'] as bool? ?? false;
      final index = posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        final post = posts[index];
        posts[index] = post.copyWith(
          isLiked: liked,
          likesCount: liked ? post.likesCount + 1 : post.likesCount - 1,
        );
      }
      final fIndex = followingPosts.indexWhere((p) => p.id == postId);
      if (fIndex != -1) {
        final post = followingPosts[fIndex];
        followingPosts[fIndex] = post.copyWith(
          isLiked: liked,
          likesCount: liked ? post.likesCount + 1 : post.likesCount - 1,
        );
      }
      for (final catId in categoryPosts.keys) {
        final catList = categoryPosts[catId] ?? [];
        final idx = catList.indexWhere((p) => p.id == postId);
        if (idx != -1) {
          final post = catList[idx];
          catList[idx] = post.copyWith(
            isLiked: liked,
            likesCount: liked ? post.likesCount + 1 : post.likesCount - 1,
          );
        }
      }
      notifyListeners();
    }
    return res;
  }

  Future<Map<String, dynamic>> toggleCollect(int postId) async {
    final res = await ApiService().post('/posts/$postId/collect');
    if (res['code'] == 200) {
      final collected = res['data']?['collected'] as bool? ?? false;
      final index = posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        final post = posts[index];
        posts[index] = post.copyWith(
          isCollected: collected,
          collectsCount: collected ? post.collectsCount + 1 : post.collectsCount - 1,
        );
      }
      final fIndex = followingPosts.indexWhere((p) => p.id == postId);
      if (fIndex != -1) {
        final post = followingPosts[fIndex];
        followingPosts[fIndex] = post.copyWith(
          isCollected: collected,
          collectsCount: collected ? post.collectsCount + 1 : post.collectsCount - 1,
        );
      }
      for (final catId in categoryPosts.keys) {
        final catList = categoryPosts[catId] ?? [];
        final idx = catList.indexWhere((p) => p.id == postId);
        if (idx != -1) {
          final post = catList[idx];
          catList[idx] = post.copyWith(
            isCollected: collected,
            collectsCount: collected ? post.collectsCount + 1 : post.collectsCount - 1,
          );
        }
      }
      notifyListeners();
    }
    return res;
  }

  Future<Map<String, dynamic>> togglePrivate(int postId) async {
    final res = await ApiService().post('/posts/$postId/private');
    if (res['code'] == 200) {
      final isPrivate = res['data']?['is_private'] as int? ?? 0;
      final index = posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        posts[index] = posts[index].copyWith(isPrivate: isPrivate);
      }
      final fIndex = followingPosts.indexWhere((p) => p.id == postId);
      if (fIndex != -1) {
        followingPosts[fIndex] = followingPosts[fIndex].copyWith(isPrivate: isPrivate);
      }
      for (final catId in categoryPosts.keys) {
        final catList = categoryPosts[catId] ?? [];
        final idx = catList.indexWhere((p) => p.id == postId);
        if (idx != -1) {
          catList[idx] = catList[idx].copyWith(isPrivate: isPrivate);
        }
      }
      notifyListeners();
    }
    return res;
  }

  Future<Map<String, dynamic>> deletePost(int postId) async {
    return await ApiService().delete('/posts/$postId');
  }

  Future<Map<String, dynamic>> pinPost(int postId, int categoryId) async {
    return await ApiService().post('/posts/$postId/pin', data: {'category_id': categoryId});
  }

  Future<Map<String, dynamic>> fetchComments(int postId, [int page = 1, int pageSize = 20, String sort = 'latest']) async {
    try {
      final res = await ApiService().get('/comments/post/$postId', queryParameters: {'page': page, 'pageSize': pageSize, 'sort': sort});
      if (res['code'] == 200) {
        final list = res['data'] as List;
        final comments = list.map((e) => Comment.fromJson(e as Map<String, dynamic>)).toList();
        final total = res['total'] as int? ?? 0;
        return {'comments': comments, 'total': total};
      }
    } catch (_) {}
    return {'comments': <Comment>[], 'total': 0};
  }

  Future<Map<String, dynamic>> addComment({
    required int postId,
    int? parentId,
    required String content,
    String imageUrl = '',
    String voiceUrl = '',
    int voiceDuration = 0,
    int? replyToUserId,
  }) async {
    return await ApiService().post('/comments', data: {
      'post_id': postId,
      'parent_id': parentId,
      'content': content,
      'image_url': imageUrl,
      'voice_url': voiceUrl,
      'voice_duration': voiceDuration,
      'reply_to_user_id': replyToUserId,
    });
  }

  Future<Map<String, dynamic>> toggleCommentLike(int commentId) async {
    return await ApiService().post('/comments/$commentId/like');
  }

  Future<Map<String, dynamic>> pinComment(int commentId) async {
    return await ApiService().post('/comments/$commentId/pin');
  }

  Future<Map<String, dynamic>> deleteComment(int commentId) async {
    return await ApiService().delete('/comments/$commentId');
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final res = await ApiService().get('/comments/search-users', queryParameters: {'q': query});
      if (res['code'] == 200) {
        return List<Map<String, dynamic>>.from(res['data']);
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchTrending() async {
    try {
      final res = await ApiService().get('/posts/trending', queryParameters: {'type': 'hot'});
      if (res['code'] == 200) {
        return List<Map<String, dynamic>>.from((res['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchUserPosts(int userId, {bool refresh = false, int? page}) async {
    try {
      final res = await ApiService().get('/users/$userId/posts', queryParameters: {
        'page': page ?? 1,
        'pageSize': 20,
      });
      if (res['code'] == 200) {
        final data = res['data'];
        if (data is List) {
          return List<Map<String, dynamic>>.from(data.map((e) => Map<String, dynamic>.from(e as Map)));
        }
        if (data is Map && data['list'] is List) {
          return List<Map<String, dynamic>>.from((data['list'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
        }
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchUserCollects(int userId, {bool refresh = false}) async {
    try {
      final res = await ApiService().get('/users/$userId/collects', queryParameters: {'pageSize': 20});
      if (res['code'] == 200) {
        final data = res['data'];
        if (data is List) {
          return List<Map<String, dynamic>>.from(data.map((e) => Map<String, dynamic>.from(e as Map)));
        }
        if (data is Map && data['list'] is List) {
          return List<Map<String, dynamic>>.from((data['list'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
        }
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchUserLikes(int userId, {bool refresh = false}) async {
    try {
      final res = await ApiService().get('/users/$userId/likes', queryParameters: {'pageSize': 20});
      if (res['code'] == 200) {
        final data = res['data'];
        if (data is List) {
          return List<Map<String, dynamic>>.from(data.map((e) => Map<String, dynamic>.from(e as Map)));
        }
        if (data is Map && data['list'] is List) {
          return List<Map<String, dynamic>>.from((data['list'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
        }
      }
    } catch (_) {}
    return [];
  }

  Future<List<String>> fetchHotTags() async {
    try {
      final res = await ApiService().get('/posts/hot-tags');
      if (res['code'] == 200) {
        final data = res['data'];
        if (data is List) {
          return data.map((e) => e.toString()).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> searchPosts(String keyword) async {
    try {
      final res = await ApiService().get('/posts/search', queryParameters: {'keyword': keyword});
      if (res['code'] == 200) {
        final data = res['data'];
        if (data is List) {
          return List<Map<String, dynamic>>.from(data.map((e) => Map<String, dynamic>.from(e as Map)));
        }
        if (data is Map && data['list'] is List) {
          return List<Map<String, dynamic>>.from((data['list'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
        }
      }
    } catch (_) {}
    return [];
  }

  Future<String?> uploadImage(String filePath) async {
    try {
      final res = await ApiService().uploadFile('/upload/single', filePath);
      if (res['code'] == 200) {
        return res['data']?['url'] as String?;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> uploadFile(String filePath) async {
    try {
      final res = await ApiService().uploadFile('/upload/single', filePath);
      if (res['code'] == 200) {
        return res['data']?['url'] as String?;
      }
    } catch (_) {}
    return null;
  }

  Future<List<String>> uploadMultiple(List<String> filePaths) async {
    final urls = <String>[];
    for (final path in filePaths) {
      final url = await uploadFile(path);
      if (url != null) urls.add(url);
    }
    return urls;
  }

  // 红包相关
  Future<Map<String, dynamic>> sendRedpacket({required int totalCoins, required int totalCount, String message = '恭喜发财', int? postId}) async {
    return await ApiService().post('/coins/redpacket/send', data: {
      'total_coins': totalCoins,
      'total_count': totalCount,
      'message': message,
      'post_id': postId,
    });
  }

  Future<Map<String, dynamic>> getCoinBalance() async {
    return await ApiService().get('/coins/balance');
  }

  // 赞赏相关
  Future<Map<String, dynamic>> appreciatePost({required int postId, required int amount}) async {
    return await ApiService().post('/coins/appreciate', data: {
      'post_id': postId,
      'amount': amount,
    });
  }

  Future<List<Map<String, dynamic>>> fetchAppreciations(int postId) async {
    try {
      final res = await ApiService().get('/coins/appreciations/$postId');
      if (res['code'] == 200) {
        final data = res['data'];
        if (data is List) {
          return List<Map<String, dynamic>>.from(data.map((e) => Map<String, dynamic>.from(e as Map)));
        }
      }
    } catch (_) {}
    return [];
  }
}
