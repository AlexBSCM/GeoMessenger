import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final title = message.notification?.title ?? 'New Geo Message!';
  final body = message.notification?.body ?? message.data['text'] ?? '';
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: androidSettings);
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(settings);
  const androidDetails = AndroidNotificationDetails(
    'geo_messages',
    'Geo Messages',
    channelDescription: 'Notifications when you enter a geofence',
    importance: Importance.high,
    priority: Priority.high,
  );
  await plugin.show(
    message.messageId.hashCode,
    title,
    body,
    const NotificationDetails(android: androidDetails),
  );
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _notifications.initialize(settings);
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  Future<void> showIncomingMessageNotification(GeoMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'geo_messages',
      'Geo Messages',
      channelDescription: 'Notifications when you receive a geo message',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.show(
      message.id.hashCode,
      'New geo message from ${message.senderName}',
      message.text,
      details,
    );
  }

  Future<void> saveToken() async {
    final token = await getFcmToken();
    if (token == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'pushToken': token});
  }

  Future<void> showGeoMessageNotification(GeoMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'geo_messages',
      'Geo Messages',
      channelDescription: 'Notifications when you enter a geofence',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.show(
      message.id.hashCode,
      'New Geo Message!',
      '${message.senderName}: ${message.text}',
      details,
    );
  }

  Future<String?> getFcmToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      return null;
    }
  }

  void onForegroundMessage(void Function(RemoteMessage) handler) {
    FirebaseMessaging.onMessage.listen(handler);
  }

  void onMessageOpenedApp(void Function(RemoteMessage) handler) {
    FirebaseMessaging.onMessageOpenedApp.listen(handler);
  }

  Future<void> requestNotificationPermission() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      // Permission not granted
    }
  }
}
