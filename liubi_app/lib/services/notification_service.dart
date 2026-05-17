import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../widgets/in_app_notification.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationTap(response.payload);
      },
    );

    const androidChannel = AndroidNotificationChannel(
      'liubi_channel',
      '留笔通知',
      description: '接收点赞、评论、关注等通知',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    const chatChannel = AndroidNotificationChannel(
      'liubi_chat',
      '聊天消息',
      description: '接收新消息通知',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(androidChannel);
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(chatChannel);
  }

  static void _handleNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    final context = navigatorKey.currentContext;
    if (context == null) return;

    if (payload.startsWith('chat:')) {
      final convId = int.tryParse(payload.substring(5));
      if (convId != null) {
        navigatorKey.currentState?.pushNamed('/chat', arguments: {'id': convId, 'name': '', 'avatar': '', 'otherUserId': 0});
      }
    } else if (payload.startsWith('like:')) {
      final postId = int.tryParse(payload.substring(5));
      if (postId != null) {
        navigatorKey.currentState?.pushNamed('/detail', arguments: postId);
      }
    } else if (payload.startsWith('comment:')) {
      final postId = int.tryParse(payload.substring(8));
      if (postId != null) {
        navigatorKey.currentState?.pushNamed('/detail', arguments: postId);
      }
    } else if (payload.startsWith('follow:')) {
      final userId = int.tryParse(payload.substring(7));
      if (userId != null) {
        navigatorKey.currentState?.pushNamed('/user-profile', arguments: userId);
      }
    } else if (payload == 'notifications') {
      navigatorKey.currentState?.pushNamed('/notifications', arguments: 'system');
    }
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    String? channelId,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId ?? 'liubi_channel',
      channelId == 'liubi_chat' ? '聊天消息' : '留笔通知',
      channelDescription: channelId == 'liubi_chat' ? '接收新消息通知' : '接收点赞、评论、关注等通知',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
      showWhen: true,
    );
    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  static void showInAppBanner({
    required String title,
    required String body,
    String? avatarUrl,
    IconData? icon,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    InAppNotification.show(
      context: context,
      title: title,
      body: body,
      avatarUrl: avatarUrl,
      icon: icon,
      iconColor: iconColor,
      onTap: onTap,
    );
  }

  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }
}
