import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../widgets/navigation/bottom_nav_bar.dart';
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
