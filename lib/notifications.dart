import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;
import 'dart:math' show Random;

class NotificationHelper {
  static final NotificationHelper _instance = NotificationHelper._internal();
  factory NotificationHelper() => _instance;
  NotificationHelper._internal();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    if (!Platform.isAndroid) return;
    var permission = await Permission.notification.status;
    if (!permission.isGranted) {
      await Permission.notification.request();
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(
            android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> showNotification(
      {required String title, required String body, bool showAvatar=true}) async {
    if(!Platform.isAndroid) return;
    AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('k96e.momotalk.notification', 'notification',
            channelDescription: 'Message notifications',
            importance: Importance.max,
            priority: Priority.high,
            icon: "@mipmap/ic_launcher",
            visibility: NotificationVisibility.public,
            largeIcon: showAvatar ? const DrawableResourceAndroidBitmap("head_round"):null,
            ticker: 'message');
    NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidNotificationDetails);
    await _notificationsPlugin.show(
      Random().nextInt(10000),
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<void> cancelAll() async {
    if(!Platform.isAndroid) return;
    await _notificationsPlugin.cancelAll();
  }
}
