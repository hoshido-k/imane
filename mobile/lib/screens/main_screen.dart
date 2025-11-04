import 'package:flutter/material.dart';
import 'schedule/schedule_list_screen.dart';
import 'favorites/favorites_screen.dart';
import 'notification/notification_history_screen.dart';
import 'debug/location_debug_screen.dart';
// import 'profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ScheduleListScreen(),
    FavoritesScreen(),
    NotificationHistoryScreen(),
    // ProfileScreen(),
  ];

  final List<String> _titles = const [
    'スケジュール',
    'お気に入り',
    '通知履歴',
    // 'プロフィール',
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        backgroundColor: _getAppBarColor(),
        actions: [
          // Debug button (for testing only)
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LocationDebugScreen(),
                ),
              );
            },
            tooltip: 'デバッグ画面',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _getAppBarColor(),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'スケジュール',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star),
            label: 'お気に入り',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: '通知履歴',
          ),
          // BottomNavigationBarItem(
          //   icon: Icon(Icons.person),
          //   label: 'プロフィール',
          // ),
        ],
      ),
    );
  }

  Color _getAppBarColor() {
    switch (_currentIndex) {
      case 0:
        return Colors.blue;
      case 1:
        return Colors.orange;
      case 2:
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }
}
