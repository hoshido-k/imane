import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'popup_notification_service.dart';
import 'local_notification_service.dart';
import '../models/notification_history.dart';

/// FCM (Firebase Cloud Messaging) service for imane
/// Handles push notification registration and receiving
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final ApiService _apiService = ApiService();

  String? _fcmToken;
  bool _isInitialized = false;

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Check if FCM is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize FCM service
  /// This should be called after user login
  Future<void> initialize() async {
    if (_isInitialized) {
      print('[FCMService] Already initialized');
      return;
    }

    try {
      // Request permission for iOS
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('[FCMService] Notification permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('[FCMService] User granted notification permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('[FCMService] User granted provisional notification permission');
      } else {
        print('[FCMService] User declined or has not accepted notification permission');
      }

      // For iOS: Get APNs token first before FCM token
      try {
        final apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken != null) {
          print('[FCMService] APNs Token obtained: ${apnsToken.substring(0, 10)}...');
        } else {
          print('[FCMService] APNs Token is null (likely running on simulator)');
        }
      } catch (e) {
        print('[FCMService] Warning: Could not get APNs token (this is expected on simulator): $e');
      }

      // Get FCM token (may fail on simulator, but that's OK)
      try {
        _fcmToken = await _firebaseMessaging.getToken();
        print('[FCMService] FCM Token obtained: $_fcmToken');

        if (_fcmToken != null) {
          // Register token with backend
          await _registerToken(_fcmToken!);
        } else {
          print('[FCMService] FCM Token is null (simulator mode - notifications will not work)');
        }
      } catch (e) {
        print('[FCMService] Could not get FCM token (this is expected on simulator): $e');
        print('[FCMService] Running in simulator mode - push notifications will not work');
      }

      // Listen to token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('[FCMService] FCM Token refreshed: $newToken');
        _fcmToken = newToken;
        _registerToken(newToken);
      });

      // Setup message handlers
      _setupMessageHandlers();

      _isInitialized = true;
      print('[FCMService] Initialization complete (simulator mode: FCM token = ${_fcmToken != null ? "available" : "unavailable"})');
    } catch (e) {
      print('[FCMService] Initialization error: $e');
      // Don't rethrow - allow app to continue even if FCM fails
      _isInitialized = false;
    }
  }

  /// Register FCM token with backend API
  Future<void> _registerToken(String token) async {
    try {
      await _apiService.post(
        '/notifications/fcm-token',
        body: {
          'fcm_token': token,
        },
        requiresAuth: true,
      );
      print('[FCMService] Token registered with backend');
    } catch (e) {
      print('[FCMService] Error registering token: $e');
      // Don't rethrow - token registration failure shouldn't block app
    }
  }

  /// Setup message handlers for foreground, background, and terminated states
  void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('[FCMService] Foreground message received');
      print('[FCMService] Message data: ${message.data}');

      if (message.notification != null) {
        print('[FCMService] Notification Title: ${message.notification!.title}');
        print('[FCMService] Notification Body: ${message.notification!.body}');
      }

      // Handle foreground notification
      _handleMessage(message);
    });

    // Background messages (app in background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('[FCMService] Background message opened');
      print('[FCMService] Message data: ${message.data}');

      // Handle notification tap
      _handleNotificationTap(message);
    });

    // Check if app was opened from terminated state by notification
    _checkInitialMessage();
  }

  /// Check if app was opened from a notification (terminated state)
  Future<void> _checkInitialMessage() async {
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();

    if (initialMessage != null) {
      print('[FCMService] App opened from terminated state by notification');
      print('[FCMService] Message data: ${initialMessage.data}');
      _handleNotificationTap(initialMessage);
    }
  }

  /// Handle incoming message (foreground)
  Future<void> _handleMessage(RemoteMessage message) async {
    print('[FCMService] Handling foreground message: ${message.messageId}');

    // Extract notification data
    final data = message.data;
    final notification = message.notification;
    final notificationType = data['type'] ?? 'arrival';

    // Check notification preferences from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
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

    // If user has disabled this notification type, skip it
    if (!shouldShow) {
      print('[FCMService] Notification type $notificationType is disabled in settings, skipping');
      return;
    }

    print('[FCMService] Notification type $notificationType is enabled, showing notification');

    // 1. Show system notification banner (iOS/Android)
    final localNotificationService = LocalNotificationService();
    localNotificationService.showNotificationFromFCM(message);

    // 2. Show in-app popup notification
    final popupService = PopupNotificationService();

    // Prepare data for popup
    final Map<String, dynamic> popupData = {
      'title': notification?.title ?? data['title'] ?? '通知',
      'body': notification?.body ?? data['body'] ?? '',
      'type': notificationType,
      'map_link': data['map_link'],
      ...data,
    };

    // Show popup
    popupService.showFromFCM(popupData, onTap: () {
      print('[FCMService] Popup notification tapped');
      // Handle tap action (just open app, not map)
      _handleNotificationTap(message);
    });
  }

  /// Open map link in external app
  Future<void> _openMapLink(String mapLink) async {
    try {
      final uri = Uri.parse(mapLink);
      print('[FCMService] Opening map link: $mapLink');

      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Open in external app (Google Maps, Apple Maps, etc.)
        );
        print('[FCMService] Map link opened successfully');
      } else {
        print('[FCMService] Cannot launch URL: $mapLink');
      }
    } catch (e) {
      print('[FCMService] Error opening map link: $e');
    }
  }

  /// Handle notification tap
  Future<void> _handleNotificationTap(RemoteMessage message) async {
    print('[FCMService] Handling notification tap: ${message.messageId}');

    final data = message.data;
    final type = data['type'];

    print('[FCMService] Notification type: $type');
    print('[FCMService] Opening app (map link available in notification actions)');

    // アプリを開くだけ（地図は通知アクションボタンから開く）
    // TODO: Navigate to appropriate screen based on notification type
  }

  /// Unregister FCM token from backend
  Future<void> unregisterToken() async {
    if (_fcmToken == null) {
      print('[FCMService] No token to unregister');
      return;
    }

    try {
      // Backend API call to remove token
      await _apiService.delete(
        '/notifications/fcm-token',
        body: {
          'fcm_token': _fcmToken!,
        },
        requiresAuth: true,
      );
      print('[FCMService] Token unregistered from backend');

      // Delete FCM token locally
      await _firebaseMessaging.deleteToken();
      _fcmToken = null;
      _isInitialized = false;

      print('[FCMService] FCM token deleted');
    } catch (e) {
      print('[FCMService] Error unregistering token: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await unregisterToken();
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('[FCMService] Background message received: ${message.messageId}');
  print('[FCMService] Message data: ${message.data}');

  if (message.notification != null) {
    print('[FCMService] Notification Title: ${message.notification!.title}');
    print('[FCMService] Notification Body: ${message.notification!.body}');
  }

  // Check notification preferences from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final notificationType = message.data['type'] ?? 'arrival';
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

  // If user has disabled this notification type, skip it
  if (!shouldShow) {
    print('[FCMService] Background: Notification type $notificationType is disabled in settings, skipping');
    return;
  }

  print('[FCMService] Background: Notification type $notificationType is enabled');
  // System notification will be shown automatically by the OS
}
