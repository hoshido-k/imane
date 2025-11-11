import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';

/// Settings screen
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        children: [
          // Title
          Text(
            '設定',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 30,
              fontWeight: FontWeight.w400,
              color: AppColors.primary,
              height: 1.2,
              letterSpacing: 0.3955,
            ),
          ),
          const SizedBox(height: 4),
          // Subtitle
          Text(
            'アプリの設定とアカウント管理',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.33,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Settings items
          _buildSettingsCard(
            icon: Icons.account_circle,
            title: 'アカウント',
            subtitle: 'プロフィールとアカウント情報',
            onTap: () {
              Navigator.of(context).pushNamed('/profile');
            },
          ),
          const SizedBox(height: 16),
          _buildSettingsCard(
            icon: Icons.notifications_outlined,
            title: '通知設定',
            subtitle: '通知の受信設定',
            onTap: () {
              // TODO: Navigate to notification settings
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('通知設定は準備中です')),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildSettingsCard(
            icon: Icons.location_on_outlined,
            title: '位置情報',
            subtitle: '位置情報の利用設定',
            onTap: () {
              // TODO: Navigate to location settings
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('位置情報設定は準備中です')),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildSettingsCard(
            icon: Icons.privacy_tip_outlined,
            title: 'プライバシー',
            subtitle: 'データの保存と削除',
            onTap: () {
              // TODO: Navigate to privacy settings
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('プライバシー設定は準備中です')),
              );
            },
          ),
          const SizedBox(height: 32),
          // Logout button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _handleLogout,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: const Text(
                'ログアウト',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.3125,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              offset: Offset(0, 1),
              blurRadius: 3,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF3D3D3D),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFF8B7969),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしますか?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _authService.logout();

      if (!mounted) return;

      // Navigate to login screen
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      print('[Settings] Error during logout: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ログアウトに失敗しました: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
