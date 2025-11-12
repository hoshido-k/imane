import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/password_reset_screen.dart';
import 'screens/main_screen.dart';
import 'screens/friends/friends_screen.dart';
import 'screens/friends/add_friend_screen.dart';
import 'screens/friends/friend_requests_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/settings/notification_settings_screen.dart';
import 'screens/settings/location_settings_screen.dart';
import 'screens/settings/privacy_settings_screen.dart';
import 'screens/notification/notification_history_screen.dart';
import 'services/auth_service.dart';
import 'services/fcm_service.dart';
import 'services/location_service.dart';
import 'services/app_lifecycle_observer.dart';
import 'services/schedule_monitor_service.dart';
import 'services/popup_notification_service.dart';
import 'services/local_notification_service.dart';

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('[Main] Background message received: ${message.messageId}');
  await firebaseMessagingBackgroundHandler(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase初期化（既に初期化されている場合はスキップ）
  try {
    print('[Main] Initializing Firebase...');
    print('[Main] Project ID: ${DefaultFirebaseOptions.currentPlatform.projectId}');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('[Main] Firebase initialized successfully');
  } catch (e) {
    // 既に初期化されている場合はエラーを無視
    if (e.toString().contains('duplicate-app')) {
      print('[Main] Firebase already initialized, skipping...');
    } else {
      print('[Main] Firebase initialization failed: $e');
      rethrow;
    }
  }

  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  print('[Main] Firebase Crashlytics initialized');

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ImaneApp());
}

/// Global navigator key for accessing context from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class ImaneApp extends StatefulWidget {
  const ImaneApp({super.key});

  @override
  State<ImaneApp> createState() => _ImaneAppState();
}

class _ImaneAppState extends State<ImaneApp> {
  final AppLifecycleObserver _lifecycleObserver = AppLifecycleObserver();

  @override
  void initState() {
    super.initState();
    // Register lifecycle observer
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    print('[ImaneApp] AppLifecycleObserver registered');
  }

  @override
  void dispose() {
    // Unregister lifecycle observer
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    print('[ImaneApp] AppLifecycleObserver unregistered');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'imane',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthCheckScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/password-reset': (context) => const PasswordResetScreen(),
        '/home': (context) => const MainScreen(),
        '/friends': (context) => const FriendsScreen(),
        '/friends/add': (context) => const AddFriendScreen(),
        '/friends/requests': (context) => const FriendRequestsScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/settings/notifications': (context) => const NotificationSettingsScreen(),
        '/settings/location': (context) => const LocationSettingsScreen(),
        '/settings/privacy': (context) => const PrivacySettingsScreen(),
        '/notifications/history': (context) => const NotificationHistoryScreen(),
      },
    );
  }
}

/// Authentication check screen (splash/loading screen)
class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    print('[AuthCheck] Checking authentication status...');
    final authService = AuthService();

    try {
      // Try to auto-login with saved token
      final isLoggedIn = await authService.autoLogin();

      if (!mounted) return;

      if (isLoggedIn) {
        print('[AuthCheck] Auto-login successful');

        // Initialize services after successful login
        await _initializeServices();

        if (!mounted) return;
        print('[AuthCheck] Navigating to home');
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        print('[AuthCheck] No valid token found, navigating to login');
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      print('[AuthCheck] Error during auth check: $e');
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  /// Initialize FCM and Location services after login
  Future<void> _initializeServices() async {
    print('[AuthCheck] Initializing services...');

    // Initialize local notification service (for system banners)
    try {
      final localNotificationService = LocalNotificationService();
      await localNotificationService.initialize();
      print('[AuthCheck] Local notification service initialized');
    } catch (e) {
      print('[AuthCheck] Local notification service initialization failed: $e');
    }

    // Initialize FCM service (non-blocking)
    try {
      final fcmService = FCMService();
      await fcmService.initialize();
      print('[AuthCheck] FCM service initialized');
    } catch (e) {
      print('[AuthCheck] FCM service initialization failed (non-critical): $e');
      // FCM failure should not block other services
    }

    // Start schedule monitoring (critical for location tracking)
    try {
      // 位置情報追跡はstart_timeから自動的に開始されます
      final scheduleMonitor = ScheduleMonitorService();
      scheduleMonitor.startMonitoring();
      print('[AuthCheck] Schedule monitoring started');
    } catch (e) {
      print('[AuthCheck] Schedule monitoring initialization failed: $e');
    }

    print('[AuthCheck] All services initialization completed');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8E4DF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'imane',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 48,
                fontWeight: FontWeight.w400,
                color: const Color(0xFFB85D4D),
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Color(0xFFB85D4D)),
            ),
          ],
        ),
      ),
    );
  }
}
