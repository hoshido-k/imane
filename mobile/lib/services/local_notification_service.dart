import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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

    // Define notification actions for iOS
    const DarwinNotificationActionOption actionOptions =
        DarwinNotificationActionOption.foreground;

    const DarwinNotificationAction openMapAction = DarwinNotificationAction(
      'open_map',
      '地図で開く',
      options: actionOptions,
    );

    const DarwinNotificationCategory mapCategory = DarwinNotificationCategory(
      'map_notification',
      actions: [openMapAction],
    );

    // iOS initialization settings with action categories
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [mapCategory],
    );

    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
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
  Future<void> _onNotificationTapped(NotificationResponse response) async {
    print('[LocalNotificationService] Notification tapped');
    print('[LocalNotificationService] Action ID: ${response.actionId}');
    print('[LocalNotificationService] Payload: ${response.payload}');

    if (response.payload == null || response.payload!.isEmpty) {
      print('[LocalNotificationService] No payload data');
      return;
    }

    try {
      // Parse payload JSON
      final payloadData = jsonDecode(response.payload!);
      final mapLink = payloadData['map_link'] as String?;

      // Check if "地図で開く" action button was tapped
      if (response.actionId == 'open_map') {
        print('[LocalNotificationService] "地図で開く" action tapped');
        if (mapLink != null && mapLink.isNotEmpty) {
          await _openMapLink(mapLink);
        } else {
          print('[LocalNotificationService] No map link in payload');
        }
      } else {
        // Regular notification tap - just open the app
        print('[LocalNotificationService] Opening app (default action)');
        // TODO: Navigate to appropriate screen
      }
    } catch (e) {
      print('[LocalNotificationService] Error parsing payload: $e');
    }
  }

  /// Open map link in external app
  Future<void> _openMapLink(String mapLink) async {
    try {
      final uri = Uri.parse(mapLink);
      print('[LocalNotificationService] Opening map link: $mapLink');

      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        print('[LocalNotificationService] Map link opened successfully');
      } else {
        print('[LocalNotificationService] Cannot launch URL: $mapLink');
      }
    } catch (e) {
      print('[LocalNotificationService] Error opening map link: $e');
    }
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

    // Check notification preferences from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final notificationType = type ?? 'arrival';
    bool shouldShow = true;

    switch (notificationType) {
      case 'arrival':
        shouldShow = prefs.getBool('notify_arrival') ?? true;
        break;
      case 'stay':
        shouldShow = prefs.getBool('notify_stay') ?? true;
        break;
      case 'departure':
        shouldShow = prefs.getBool('notify_departure') ?? true;
        break;
    }

    // Check sound and badge settings
    final enableSound = prefs.getBool('notify_sound') ?? true;
    final enableBadge = prefs.getBool('notify_badge') ?? true;

    // If user has disabled this notification type, skip it
    if (!shouldShow) {
      print('[LocalNotificationService] Notification type $notificationType is disabled in settings, skipping');
      return;
    }

    print('[LocalNotificationService] Notification type $notificationType is enabled, showing notification');

    // Check if map link is available
    final mapLink = data['map_link'] as String?;
    final hasMapLink = mapLink != null && mapLink.isNotEmpty;

    // iOS notification details (apply user preferences and action category)
    final DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: enableBadge,
      presentSound: enableSound,
      categoryIdentifier: hasMapLink ? 'map_notification' : null, // Add action buttons if map link is available
    );

    // Android notification details with action button (apply user preferences)
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'imane_notifications', // channel id
      'imane通知', // channel name
      channelDescription: '到着・滞在・出発通知',
      importance: Importance.high,
      priority: Priority.high,
      playSound: enableSound,
      enableVibration: enableSound, // Vibrate with sound
      actions: hasMapLink ? [
        const AndroidNotificationAction(
          'open_map',
          '地図で開く',
          showsUserInterface: true,
          cancelNotification: false,
        ),
      ] : null,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      iOS: iOSDetails,
      android: androidDetails,
    );

    // Generate unique notification ID based on message ID or timestamp
    final notificationId = message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch;

    // Prepare payload with notification data (including map link)
    final payloadData = {
      'message_id': message.messageId,
      'type': type,
      'map_link': data['map_link'],
    };
    final payload = jsonEncode(payloadData);

    try {
      await _notificationsPlugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payload,
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
