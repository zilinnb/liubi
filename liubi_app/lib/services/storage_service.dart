import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _tokenKey = 'token';
  static const String _userInfoKey = 'userInfo';
  static const String _chatMsgPrefix = 'chat_msg_';
  static const int _maxLocalMsgs = 200;

  // 缓存key前缀
  static const String _notificationsPrefix = 'cache_notif_';
  static const String _discoverTrendingKey = 'cache_discover_trending';
  static const String _discoverUsersKey = 'cache_discover_users';
  static const String _discoverStatsKey = 'cache_discover_stats';
  static const String _userProfilePrefix = 'cache_profile_';
  static const String _userPostsPrefix = 'cache_user_posts_';
  static const int _cacheExpiryMinutes = 30;

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<Map<String, dynamic>?> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userInfoKey);
    if (raw == null) return null;
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setUserInfo(Map<String, dynamic> userInfo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userInfoKey, json.encode(userInfo));
  }

  static Future<List<Map<String, dynamic>>> getChatMessages(int conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_chatMsgPrefix$conversationId');
    if (raw == null) return [];
    try {
      final list = json.decode(raw) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveChatMessages(int conversationId, List<Map<String, dynamic>> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = messages.length > _maxLocalMsgs
        ? messages.sublist(messages.length - _maxLocalMsgs)
        : messages;
    await prefs.setString('$_chatMsgPrefix$conversationId', json.encode(trimmed));
  }

  static Future<void> appendChatMessages(int conversationId, List<Map<String, dynamic>> newMsgs) async {
    final existing = await getChatMessages(conversationId);
    final existingIds = <dynamic>{};
    final existingContentKeys = <String>{};
    for (final m in existing) {
      if (m['id'] != null) {
        existingIds.add(m['id']);
      } else {
        final key = '${m['sender_id']}_${m['content']}_${m['created_at']}';
        existingContentKeys.add(key);
      }
    }
    for (final m in newMsgs) {
      if (m['id'] != null && existingIds.contains(m['id'])) continue;
      if (m['id'] == null) {
        final key = '${m['sender_id']}_${m['content']}_${m['created_at']}';
        if (existingContentKeys.contains(key)) continue;
      }
      existing.add(m);
    }
    existing.sort((a, b) {
      final ta = a['created_at'] as String? ?? '';
      final tb = b['created_at'] as String? ?? '';
      return ta.compareTo(tb);
    });
    await saveChatMessages(conversationId, existing);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userInfoKey);
    final keys = prefs.getKeys().where((k) => k.startsWith(_chatMsgPrefix));
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  static const String _searchHistoryKey = 'searchHistory';

  static Future<List<String>> getSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_searchHistoryKey) ?? [];
  }

  static Future<void> saveSearchHistory(List<String> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_searchHistoryKey, history);
  }

  // ===== 通用缓存方法 =====
  static Future<void> _saveCache(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    final cache = {'data': data, 'ts': DateTime.now().millisecondsSinceEpoch};
    await prefs.setString(key, json.encode(cache));
  }

  static Future<dynamic> _getCache(String key, {int expiryMinutes = _cacheExpiryMinutes}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      final cache = json.decode(raw) as Map<String, dynamic>;
      final ts = cache['ts'] as int? ?? 0;
      // 过期仍返回数据（离线可用），只是标记为过期
      return cache['data'];
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _isCacheExpired(String key, {int expiryMinutes = _cacheExpiryMinutes}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return true;
    try {
      final cache = json.decode(raw) as Map<String, dynamic>;
      final ts = cache['ts'] as int? ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      return age > expiryMinutes * 60 * 1000;
    } catch (_) {
      return true;
    }
  }

  // ===== 通知缓存 =====
  static Future<void> saveNotifications(String type, String? subType, List<Map<String, dynamic>> list) async {
    final key = '$_notificationsPrefix${type}_${subType ?? 'all'}';
    await _saveCache(key, list);
  }

  static Future<List<Map<String, dynamic>>> getNotifications(String type, String? subType) async {
    final key = '$_notificationsPrefix${type}_${subType ?? 'all'}';
    final data = await _getCache(key);
    if (data is List) return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return [];
  }

  // ===== 发现页缓存 =====
  static Future<void> saveDiscoverTrending(List<Map<String, dynamic>> list) async {
    await _saveCache(_discoverTrendingKey, list);
  }

  static Future<List<Map<String, dynamic>>> getDiscoverTrending() async {
    final data = await _getCache(_discoverTrendingKey);
    if (data is List) return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return [];
  }

  static Future<void> saveDiscoverUsers(List<Map<String, dynamic>> list) async {
    await _saveCache(_discoverUsersKey, list);
  }

  static Future<List<Map<String, dynamic>>> getDiscoverUsers() async {
    final data = await _getCache(_discoverUsersKey);
    if (data is List) return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return [];
  }

  static Future<void> saveDiscoverStats(Map<String, dynamic> stats) async {
    await _saveCache(_discoverStatsKey, stats);
  }

  static Future<Map<String, dynamic>?> getDiscoverStats() async {
    final data = await _getCache(_discoverStatsKey);
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  static Future<bool> isDiscoverCacheExpired() async {
    return await _isCacheExpired(_discoverTrendingKey);
  }

  // ===== 用户主页缓存 =====
  static Future<void> saveUserProfile(int userId, Map<String, dynamic> profile) async {
    await _saveCache('$_userProfilePrefix$userId', profile);
  }

  static Future<Map<String, dynamic>?> getUserProfile(int userId) async {
    final data = await _getCache('$_userProfilePrefix$userId');
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  static Future<void> saveUserPosts(int userId, String tabKey, List<Map<String, dynamic>> list) async {
    await _saveCache('$_userPostsPrefix${userId}_$tabKey', list);
  }

  static Future<List<Map<String, dynamic>>> getUserPosts(int userId, String tabKey) async {
    final data = await _getCache('$_userPostsPrefix${userId}_$tabKey');
    if (data is List) return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return [];
  }
}
