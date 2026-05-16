import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _tokenKey = 'token';
  static const String _userInfoKey = 'userInfo';
  static const String _chatMsgPrefix = 'chat_msg_';
  static const int _maxLocalMsgs = 200;

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
}
