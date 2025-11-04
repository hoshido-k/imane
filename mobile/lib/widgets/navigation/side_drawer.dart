import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../screens/profile/profile_screen.dart';

class SideDrawer extends StatelessWidget {
  const SideDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.backgroundDark2,
      child: SafeArea(
        child: Column(
          children: [
            // Profile Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.backgroundGradient,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.borderGray.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF60A5FA), Color(0xFFA78BFA)],
                      ),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.person,
                        size: 40,
                        color: AppColors.textWhite,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Username
                  const Text(
                    'ユーザー名',
                    style: TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'user@example.com',
                    style: TextStyle(
                      color: AppColors.textGray,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _DrawerMenuItem(
                    icon: Icons.person_outline,
                    title: 'プロフィール',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      );
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.edit_outlined,
                    title: 'プロフィール編集',
                    onTap: () {
                      Navigator.of(context).pop();
                      // TODO: Navigate to edit profile
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('プロフィール編集は今後実装予定です')),
                      );
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.settings_outlined,
                    title: '設定',
                    onTap: () {
                      Navigator.of(context).pop();
                      // TODO: Navigate to settings
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('設定は今後実装予定です')),
                      );
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.notifications_outlined,
                    title: '通知設定',
                    onTap: () {
                      Navigator.of(context).pop();
                      // TODO: Navigate to notification settings
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('通知設定は今後実装予定です')),
                      );
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.privacy_tip_outlined,
                    title: 'プライバシー',
                    onTap: () {
                      Navigator.of(context).pop();
                      // TODO: Navigate to privacy settings
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('プライバシー設定は今後実装予定です')),
                      );
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.help_outline,
                    title: 'ヘルプ',
                    onTap: () {
                      Navigator.of(context).pop();
                      // TODO: Navigate to help
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ヘルプは今後実装予定です')),
                      );
                    },
                  ),
                  const Divider(
                    color: AppColors.borderGray,
                    height: 32,
                    indent: 16,
                    endIndent: 16,
                  ),
                  _DrawerMenuItem(
                    icon: Icons.logout,
                    title: 'ログアウト',
                    textColor: AppColors.error,
                    onTap: () {
                      Navigator.of(context).pop();
                      _showLogoutDialog(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'ログアウト',
          style: TextStyle(color: AppColors.textWhite),
        ),
        content: const Text(
          '本当にログアウトしますか？',
          style: TextStyle(color: AppColors.textGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            },
            child: const Text(
              'ログアウト',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? textColor;
  final VoidCallback onTap;

  const _DrawerMenuItem({
    required this.icon,
    required this.title,
    this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? AppColors.textWhite;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
      hoverColor: AppColors.cardBackground.withValues(alpha: 0.5),
    );
  }
}
