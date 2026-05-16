import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        if (payload.startsWith('chat:')) {
          final convId = int.tryParse(payload.substring(5));
          if (convId != null) {
            navigatorKey.currentState?.pushNamed('/chat', arguments: {'id': convId, 'name': '', 'avatar': '', 'otherUserId': 0});
          }
        } else if (payload == 'notifications') {
          navigatorKey.currentState?.pushNamed('/notifications', arguments: 'system');
        }
      },
    );

    const androidChannel = AndroidNotificationChannel(
      'liubi_channel',
      '留笔通知',
      description: '接收点赞、评论、关注等通知',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const chatChannel = AndroidNotificationChannel(
      'liubi_chat',
      '聊天消息',
      description: '接收新消息通知',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(androidChannel);
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(chatChannel);
  }

  static Future<void> showNotification({required String title, required String body, String? payload, String? channelId}) async {
    final androidDetails = AndroidNotificationDetails(
      channelId ?? 'liubi_channel',
      channelId == 'liubi_chat' ? '聊天消息' : '留笔通知',
      channelDescription: channelId == 'liubi_chat' ? '接收新消息通知' : '接收点赞、评论、关注等通知',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
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

  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }
}
