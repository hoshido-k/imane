import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../widgets/navigation/bottom_nav_bar.dart';
import '../services/fcm_service.dart';
import '../services/local_notification_service.dart';
import '../services/schedule_monitor_service.dart';
import 'schedule/schedule_list_screen.dart';
import 'friends/friends_screen.dart';
import 'settings/settings_screen.dart';

/// Main screen with bottom navigation bar (Figma design)
/// Three tabs: Schedule, Friends, Settings
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ScheduleListScreen(),
    FriendsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  /// Initialize FCM and other services after login
  Future<void> _initializeServices() async {
    print('[MainScreen] Initializing services...');

    // Initialize local notification service (for system banners)
    try {
      final localNotificationService = LocalNotificationService();
      await localNotificationService.initialize();
      print('[MainScreen] Local notification service initialized');
    } catch (e) {
      print('[MainScreen] Local notification service initialization failed: $e');
    }

    // Initialize FCM service (non-blocking)
    try {
      final fcmService = FCMService();
      if (!fcmService.isInitialized) {
        await fcmService.initialize();
        print('[MainScreen] FCM service initialized');
      } else {
        print('[MainScreen] FCM service already initialized');
      }
    } catch (e) {
      print('[MainScreen] FCM service initialization failed (non-critical): $e');
      // FCM failure should not block other services
    }

    // Start schedule monitoring (critical for location tracking)
    try {
      final scheduleMonitor = ScheduleMonitorService();
      scheduleMonitor.startMonitoring();
      print('[MainScreen] Schedule monitoring started');
    } catch (e) {
      print('[MainScreen] Schedule monitoring initialization failed: $e');
    }

    print('[MainScreen] All services initialization completed');
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}
