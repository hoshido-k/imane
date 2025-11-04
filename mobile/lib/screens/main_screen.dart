import 'package:flutter/material.dart';
import '../widgets/navigation/bottom_nav_bar.dart';
import '../widgets/navigation/side_drawer.dart';
import 'map/map_screen.dart';
import 'reactions/reactions_screen.dart';
import 'chat/chat_list_screen.dart';
// import 'profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _screens = const [
    MapScreen(),
    ReactionsScreen(),
    // TODO: フレンド一覧スクリーン
    ChatListScreen(),
    // ProfileScreen(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const SideDrawer(),
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
