import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';
import 'popup_notification_service.dart';
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

      // Get FCM token
      _fcmToken = await _firebaseMessaging.getToken();
      print('[FCMService] FCM Token: $_fcmToken');

      if (_fcmToken != null) {
        // Register token with backend
        await _registerToken(_fcmToken!);
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
      print('[FCMService] Initialization complete');
    } catch (e) {
      print('[FCMService] Initialization error: $e');
      rethrow;
    }
  }

  /// Register FCM token with backend API
  Future<void> _registerToken(String token) async {
    try {
      await _apiService.post(
        '/notifications/register',
        body: {
          'fcm_token': token,
          'device_type': 'ios', // iOS for MVP
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
  void _handleMessage(RemoteMessage message) {
    print('[FCMService] Handling foreground message: ${message.messageId}');

    // Show popup notification for foreground messages
    final popupService = PopupNotificationService();

    // Extract notification data
    final data = message.data;
    final notification = message.notification;

    // Prepare data for popup
    final Map<String, dynamic> popupData = {
      'title': notification?.title ?? data['title'] ?? '通知',
      'body': notification?.body ?? data['body'] ?? '',
      'type': data['type'] ?? 'arrival',
      'map_link': data['map_link'],
      ...data,
    };

    // Show popup
    popupService.showFromFCM(popupData, onTap: () {
      print('[FCMService] Popup notification tapped');
      // Handle tap action (e.g., navigate to notification history screen)
      _handleNotificationTap(message);
    });
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    // TODO: Navigate to appropriate screen based on notification data
    print('[FCMService] Handling notification tap: ${message.messageId}');

    final data = message.data;
    if (data.containsKey('type')) {
      final type = data['type'];
      print('[FCMService] Notification type: $type');

      // Navigate based on notification type
      // This will be implemented when we have navigation context
    }
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
        '/notifications/unregister',
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
}
