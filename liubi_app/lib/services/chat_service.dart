import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_service.dart';
import 'notification_service.dart';

class ChatService extends ChangeNotifier with WidgetsBindingObserver {
  ChatService._internal();
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;

  static const String _wsUrl = 'ws://36.140.128.103:3000/ws';
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const Duration _reconnectDelay = Duration(seconds: 3);
  static const int _maxReconnectAttempts = 10;

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _isConnected = false;
  bool _intentionalDisconnect = false;
  Completer<void>? _connectCompleter;
  bool _isAppInForeground = true;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  bool get isConnected => _isConnected;

  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppInForeground = state == AppLifecycleState.resumed;
    if (_isAppInForeground && !_isConnected && !_intentionalDisconnect) {
      connect();
    }
  }

  void initLifecycle() {
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> connect() async {
    _intentionalDisconnect = false;

    if (_isConnected && _channel != null) return;

    final token = await StorageService.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('[ChatService] 未获取到 token，无法连接');
      return;
    }

    final uri = Uri.parse('$_wsUrl?token=$token');
    debugPrint('[ChatService] 正在连接: $uri');

    try {
      _connectCompleter = Completer<void>();
      _channel = WebSocketChannel.connect(uri);
      _channel!.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      await _channel!.ready;

      _isConnected = true;
      _reconnectAttempts = 0;
      _startHeartbeat();
      _connectCompleter!.complete();
      notifyListeners();
      debugPrint('[ChatService] 连接成功');
    } catch (e) {
      debugPrint('[ChatService] 连接异常: $e');
      _isConnected = false;
      _connectCompleter?.completeError(e);
      notifyListeners();
      _scheduleReconnect();
    }
  }

  void disconnect() {
    _intentionalDisconnect = true;
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;

    _channel?.sink.close();
    _channel = null;

    _isConnected = false;
    notifyListeners();
    debugPrint('[ChatService] 已主动断开连接');
  }

  Future<void> sendMessage(int conversationId, String content, int msgType, {int? voiceDuration}) async {
    if (!_isConnected || _channel == null) {
      debugPrint('[ChatService] 未连接，尝试重连...');
      await connect();
      if (!_isConnected || _channel == null) {
        debugPrint('[ChatService] 重连失败，无法发送消息');
        throw Exception('WebSocket未连接');
      }
    }

    final msgData = {
      'type': 'chat',
      'conversation_id': conversationId,
      'content': content,
      'msg_type': msgType,
    };
    if (voiceDuration != null && msgType == 4) {
      msgData['voice_duration'] = voiceDuration;
    }

    final message = json.encode(msgData);

    _channel!.sink.add(message);
    debugPrint('[ChatService] 已发送消息: type=chat, conv=$conversationId');
  }

  Future<void> recallMessage(int messageId, int conversationId) async {
    if (!_isConnected || _channel == null) {
      await connect();
      if (!_isConnected || _channel == null) return;
    }

    final message = json.encode({
      'type': 'recall',
      'message_id': messageId,
      'conversation_id': conversationId,
    });

    _channel!.sink.add(message);
    debugPrint('[ChatService] 已发送撤回: msg=$messageId');
  }

  void sendRaw(Map<String, dynamic> data) {
    if (!_isConnected || _channel == null) return;
    _channel!.sink.add(json.encode(data));
  }

  void _onData(dynamic data) {
    try {
      final Map<String, dynamic> parsed = json.decode(data as String);
      final type = parsed['type'];
      if (type == 'chat' || type == 'recall' || type == 'notification' || type == 'online') {
        _messageController.add(parsed);
        if (type == 'chat') {
          _handleChatNotification(parsed);
        } else if (type == 'notification') {
          final notifData = parsed['data'] as Map<String, dynamic>?;
          if (notifData != null) {
            _handleSocialNotification(notifData);
          }
        }
      } else if (type == 'pong') {
        debugPrint('[ChatService] 收到 pong');
      }
    } catch (e) {
      debugPrint('[ChatService] 消息解析失败: $e');
    }
  }

  Future<void> _handleChatNotification(Map<String, dynamic> msg) async {
    final data = msg['data'] as Map<String, dynamic>?;
    if (data == null) return;
    final senderName = data['sender_name'] as String? ?? '';
    final content = data['content'] as String? ?? '';
    final convId = data['conversation_id'];
    final senderAvatar = data['sender_avatar'] as String? ?? '';
    if (senderName.isEmpty && content.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final chatNotifEnabled = prefs.getBool('notify_chat') ?? true;
    if (!chatNotifEnabled) return;

    String displayContent = content;
    final msgType = data['type'] as int? ?? 1;
    if (msgType == 2) displayContent = '[图片]';
    if (msgType == 3) displayContent = '[语音]';

    final title = senderName.isNotEmpty ? senderName : '新消息';
    final payload = 'chat:$convId';

    if (_isAppInForeground) {
      NotificationService.showInAppBanner(
        title: title,
        body: displayContent,
        avatarUrl: senderAvatar,
        icon: Icons.chat_bubble,
        iconColor: const Color(0xFF07C160),
        onTap: () {
          final id = convId is int ? convId : int.tryParse(convId.toString());
          if (id != null) {
            navigatorKey.currentState?.pushNamed('/chat', arguments: {
              'id': id,
              'name': senderName,
              'avatar': senderAvatar,
              'otherUserId': data['sender_id'] ?? 0,
            });
          }
        },
      );
    } else {
      await NotificationService.showNotification(
        title: title,
        body: displayContent,
        payload: payload,
        channelId: 'liubi_chat',
      );
    }
  }

  Future<void> _handleSocialNotification(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final pushEnabled = prefs.getBool('push_enabled') ?? true;
    if (!pushEnabled) return;

    final notifType = data['notif_type'] as int?;
    if (notifType == null) return;

    final fromUserName = data['from_user_name'] as String? ?? '';
    final fromUserAvatar = data['from_user_avatar'] as String? ?? '';
    final targetTitle = data['target_title'] as String? ?? '';
    final targetId = data['target_id'];
    final fromUserId = data['from_user_id'];

    String title;
    String body;
    bool enabled;
    IconData icon;
    Color iconColor;
    String payload;

    switch (notifType) {
      case 1:
        enabled = prefs.getBool('notify_like') ?? true;
        title = fromUserName.isNotEmpty ? '$fromUserName 赞了你' : '新的赞';
        body = targetTitle.isNotEmpty ? targetTitle : '有人赞了你的内容';
        icon = Icons.favorite;
        iconColor = const Color(0xFFFF2442);
        payload = 'like:$targetId';
      case 2:
        enabled = prefs.getBool('notify_comment') ?? true;
        title = fromUserName.isNotEmpty ? '$fromUserName 评论了你' : '新的评论';
        body = targetTitle.isNotEmpty ? targetTitle : '有人评论了你的内容';
        icon = Icons.chat_bubble_outline;
        iconColor = const Color(0xFF4A90D9);
        payload = 'comment:$targetId';
      case 3:
        enabled = prefs.getBool('notify_follow') ?? true;
        title = fromUserName.isNotEmpty ? '$fromUserName 关注了你' : '新的关注';
        body = fromUserName.isNotEmpty ? '快去看看吧' : '有人关注了你';
        icon = Icons.person_add;
        iconColor = const Color(0xFF07C160);
        payload = 'follow:$fromUserId';
      case 6:
        enabled = prefs.getBool('notify_collect') ?? true;
        title = fromUserName.isNotEmpty ? '$fromUserName 收藏了你' : '新的收藏';
        body = targetTitle.isNotEmpty ? targetTitle : '有人收藏了你的内容';
        icon = Icons.bookmark;
        iconColor = const Color(0xFFFFAA00);
        payload = 'like:$targetId';
      default:
        return;
    }

    if (!enabled) return;

    if (_isAppInForeground) {
      NotificationService.showInAppBanner(
        title: title,
        body: body,
        avatarUrl: fromUserAvatar,
        icon: icon,
        iconColor: iconColor,
        onTap: () {
          if (notifType == 3) {
            final uid = fromUserId is int ? fromUserId : int.tryParse(fromUserId.toString());
            if (uid != null) {
              navigatorKey.currentState?.pushNamed('/user-profile', arguments: uid);
            }
          } else {
            final pid = targetId is int ? targetId : int.tryParse(targetId.toString());
            if (pid != null) {
              navigatorKey.currentState?.pushNamed('/detail', arguments: pid);
            }
          }
        },
      );
    } else {
      await NotificationService.showNotification(
        title: title,
        body: body,
        payload: payload,
      );
    }
  }

  void _onError(dynamic error) {
    debugPrint('[ChatService] 连接错误: $error');
    _isConnected = false;
    _stopHeartbeat();
    notifyListeners();
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('[ChatService] 连接已关闭');
    _isConnected = false;
    _stopHeartbeat();
    notifyListeners();

    if (!_intentionalDisconnect) {
      _scheduleReconnect();
    }
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (_isConnected && _channel != null) {
        _channel!.sink.add(json.encode({'type': 'ping'}));
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _scheduleReconnect() {
    if (_intentionalDisconnect) return;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[ChatService] 已达到最大重连次数，停止重连');
      return;
    }

    _reconnectAttempts++;
    final delay = _reconnectDelay * _reconnectAttempts;
    debugPrint('[ChatService] 将在 ${delay.inSeconds} 秒后重连 (第$_reconnectAttempts次)');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      connect();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    disconnect();
    _messageController.close();
    super.dispose();
  }
}
