import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_colors.dart';
import '../../core/config/location_config.dart';

/// Location settings screen
class LocationSettingsScreen extends StatefulWidget {
  const LocationSettingsScreen({super.key});

  @override
  State<LocationSettingsScreen> createState() => _LocationSettingsScreenState();
}

class _LocationSettingsScreenState extends State<LocationSettingsScreen> {
  PermissionStatus _locationPermissionStatus = PermissionStatus.denied;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
  }

  Future<void> _checkPermissionStatus() async {
    setState(() => _isLoading = true);
    try {
      final status = await Permission.locationAlways.status;
      setState(() {
        _locationPermissionStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      print('[LocationSettings] Error checking permission: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openLocationSettings() async {
    await openAppSettings();
    // Refresh status when returning
    await Future.delayed(const Duration(seconds: 1));
    _checkPermissionStatus();
  }

  String _getPermissionStatusText() {
    switch (_locationPermissionStatus) {
      case PermissionStatus.granted:
        return '常に許可';
      case PermissionStatus.limited:
        return '使用中のみ許可';
      case PermissionStatus.denied:
        return '許可されていません';
      case PermissionStatus.permanentlyDenied:
        return '許可が拒否されています';
      default:
        return '不明';
    }
  }

  Color _getPermissionStatusColor() {
    switch (_locationPermissionStatus) {
      case PermissionStatus.granted:
        return const Color(0xFF4CAF50);
      case PermissionStatus.limited:
        return const Color(0xFFFF9800);
      case PermissionStatus.denied:
      case PermissionStatus.permanentlyDenied:
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getPermissionStatusIcon() {
    switch (_locationPermissionStatus) {
      case PermissionStatus.granted:
        return Icons.check_circle;
      case PermissionStatus.limited:
        return Icons.warning;
      case PermissionStatus.denied:
      case PermissionStatus.permanentlyDenied:
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF3D3D3D)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '位置情報設定',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFF3D3D3D),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Permission status card
                    _buildPermissionStatusCard(),
                    const SizedBox(height: 24),

                    // Settings section
                    _buildSectionTitle('位置情報の設定'),
                    const SizedBox(height: 8),
                    _buildDevelopmentNotice(),
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      icon: Icons.timer,
                      title: '更新間隔',
                      value: '${LocationConfig.locationUpdateIntervalMs ~/ 60000}分',
                      subtitle: 'バックグラウンドで位置情報を更新',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      icon: Icons.place,
                      title: '到着判定距離',
                      value: '${LocationConfig.distanceFilterMeters.toInt()}メートル',
                      subtitle: '目的地の到着を判定する半径',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      icon: Icons.schedule,
                      title: '滞在時間通知',
                      value: '${LocationConfig.defaultStayDurationMinutes}分',
                      subtitle: '滞在後に通知を送信',
                    ),
                    const SizedBox(height: 32),

                    // How it works section
                    _buildSectionTitle('位置情報の利用について'),
                    const SizedBox(height: 16),
                    _buildHowItWorksBox(),
                    const SizedBox(height: 24),

                    // Privacy notice
                    _buildPrivacyNoticeBox(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF3D3D3D),
      ),
    );
  }

  Widget _buildPermissionStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(0, 2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getPermissionStatusColor().withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getPermissionStatusIcon(),
                  color: _getPermissionStatusColor(),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '位置情報の許可',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3D3D3D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getPermissionStatusText(),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _getPermissionStatusColor(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_locationPermissionStatus != PermissionStatus.granted) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFFF9800),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'imaneを正常に利用するには「常に許可」が必要です',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _openLocationSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                '設定を開く',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
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
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF3D3D3D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textSecondary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '位置情報の仕組み',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildBulletPoint('スケジュールが設定されている間のみ追跡'),
          _buildBulletPoint('バックグラウンドで自動的に位置情報を更新'),
          _buildBulletPoint('目的地への到着・出発を自動検知'),
          _buildBulletPoint('通知は選択したフレンドにのみ送信'),
        ],
      ),
    );
  }

  Widget _buildPrivacyNoticeBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'プライバシー保護',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '位置情報データは24時間後に自動削除されます。詳しくはプライバシー設定をご確認ください。',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevelopmentNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFF9800).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.construction,
            color: Color(0xFFFF9800),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '各設定項目は今後のアップデートで変更可能になる予定です',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 6, right: 8),
            decoration: BoxDecoration(
              color: AppColors.textSecondary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
