import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../screens/customer_dashboard.dart';
import '../screens/restaurant_dashboard.dart';
import 'firebase_service.dart';

class NotificationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Initialize local system notifications
  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _handleNotificationClick(payload);
        }
      },
    );

    // Prompt user for notification permissions on Android 13+ at launch
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Handle user clicking on a system notification
  static void _handleNotificationClick(String payload) {
    if (payload == 'orders') {
      // Navigate to CustomerDashboard with the orders tab (tab 1) selected
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const CustomerDashboard(initialTab: 1),
        ),
        (route) => false,
      );
    } else if (payload == 'support') {
      final role = FirebaseService.currentUser?.role;
      if (role == 'admin' || role == 'support_manager' || role == 'support') {
        // Support staff or admins should be navigated to their support queue console inside RestaurantDashboard!
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const RestaurantDashboard(initialTab: 0),
          ),
          (route) => false,
        );
      } else {
        // Customer should be navigated to CustomerDashboard with profile/support selected
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const CustomerDashboard(initialTab: 2),
          ),
          (route) => false,
        );
      }
    }
  }

  /// Trigger a system-level background local notification
  static Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'support_channel_id',
      'Canlı Destek Bildirimleri',
      channelDescription: 'Yeni destek talepleri için sistem bildirim kanalı',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }
}
