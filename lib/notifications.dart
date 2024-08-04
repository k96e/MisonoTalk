import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math' show Random;

class NotificationHelper {
  static final NotificationHelper _instance = NotificationHelper._internal();
  factory NotificationHelper() => _instance;
  NotificationHelper._internal();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
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
      {required String title, required String body}) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('k96e.momotalk.notification', 'notification',
            channelDescription: 'Message notifications',
            importance: Importance.max,
            priority: Priority.high,
            icon: "@mipmap/ic_launcher",
            visibility: NotificationVisibility.public,
            largeIcon: DrawableResourceAndroidBitmap("head_round"),
            ticker: 'message');
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidNotificationDetails);
    await _notificationsPlugin.show(
      Random().nextInt(10000),
      title,
      body,
      platformChannelSpecifics,
    );
  }
}
