import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';


class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // 1. Request Permission
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Setup Local Notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(initSettings);

    // Create Channel (Required for Android 8+)
    const channel = AndroidNotificationChannel(
      'order_updates', // id
      'Order Updates', // title
      description: 'Notifications for order status changes',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    print("Notification Service Initialized");

    // 3. Foreground Handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
       print("Foreground Notification Received: ${message.notification?.title}");
       _showLocalNotification(message);
    });
  }

  Future<String?> getDeviceToken() async {
    final token = await _fcm.getToken();
    print("FCM Device Token: $token");
    return token;
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null && android != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'order_updates',
            'Order Updates',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
      print("Local Notification Displayed");
    } else {
      print("Formatting Error: Notification is null or Android details missing");
    }
  }
}
