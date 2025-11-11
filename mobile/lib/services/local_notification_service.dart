import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Local notification service for showing system notification banners
/// This is used to display notifications when the app is in foreground
class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize local notifications
  Future<void> initialize() async {
    if (_isInitialized) {
      print('[LocalNotificationService] Already initialized');
      return;
    }

    // iOS initialization settings
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
    print('[LocalNotificationService] Initialized successfully');
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('[LocalNotificationService] Notification tapped: ${response.payload}');
    // TODO: Navigate to appropriate screen based on payload
  }

  /// Show notification from FCM RemoteMessage
  Future<void> showNotificationFromFCM(RemoteMessage message) async {
    if (!_isInitialized) {
      print('[LocalNotificationService] Not initialized, skipping notification');
      return;
    }

    print('[LocalNotificationService] Showing notification from FCM');

    final notification = message.notification;
    final data = message.data;

    // Extract notification details
    final title = notification?.title ?? data['title'] ?? '通知';
    final body = notification?.body ?? data['body'] ?? '';
    final type = data['type'] as String?;

    // iOS notification details
    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Android notification details
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'imane_notifications', // channel id
      'imane通知', // channel name
      channelDescription: '到着・滞在・出発通知',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      iOS: iOSDetails,
      android: androidDetails,
    );

    // Generate unique notification ID based on message ID or timestamp
    final notificationId = message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch;

    try {
      await _notificationsPlugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: message.messageId,
      );
      print('[LocalNotificationService] Notification shown successfully');
    } catch (e) {
      print('[LocalNotificationService] Error showing notification: $e');
    }
  }

  /// Request notification permissions (iOS)
  Future<bool> requestPermissions() async {
    final result = await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    print('[LocalNotificationService] Permission result: $result');
    return result ?? false;
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
    print('[LocalNotificationService] All notifications cancelled');
  }

  /// Cancel notification by ID
  Future<void> cancel(int id) async {
    await _notificationsPlugin.cancel(id);
    print('[LocalNotificationService] Notification $id cancelled');
  }
}
