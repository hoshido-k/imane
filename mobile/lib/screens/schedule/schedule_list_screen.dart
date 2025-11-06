import 'package:flutter/material.dart';
import '../../models/schedule.dart';
import '../../services/api_service.dart';
import '../../core/constants/app_colors.dart';
import 'create_schedule_flow.dart';
import 'dart:io';

/// Schedule list screen (Home screen)
class ScheduleListScreen extends StatefulWidget {
  const ScheduleListScreen({super.key});

  @override
  State<ScheduleListScreen> createState() => _ScheduleListScreenState();
}

class _ScheduleListScreenState extends State<ScheduleListScreen> with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  List<LocationSchedule> _schedules = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSchedules();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App returned to foreground, reload schedules
      _loadSchedules();
    }
  }

  /// Load schedules from API
  Future<void> _loadSchedules() async {
    print('[ScheduleList] ========================================');
    print('[ScheduleList] Loading schedules...');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('[ScheduleList] Making GET request to /schedules...');
      final response = await _apiService.get('/schedules');
      print('[ScheduleList] Raw response: $response');
      print('[ScheduleList] Response type: ${response.runtimeType}');

      // Handle different response formats
      List<dynamic> schedulesJson;
      if (response is List) {
        print('[ScheduleList] Response is a List');
        schedulesJson = response;
      } else if (response is Map && response['schedules'] != null) {
        print('[ScheduleList] Response is a Map with schedules key');
        schedulesJson = response['schedules'];
        print('[ScheduleList] Total count from API: ${response['total']}');
      } else {
        print('[ScheduleList] Response format not recognized, using empty list');
        schedulesJson = [];
      }

      print('[ScheduleList] Found ${schedulesJson.length} schedules in response');

      if (schedulesJson.isNotEmpty) {
        print('[ScheduleList] First schedule data: ${schedulesJson[0]}');
      }

      setState(() {
        _schedules = schedulesJson
            .map((json) {
              try {
                return LocationSchedule.fromJson(json);
              } catch (e) {
                print('[ScheduleList] Error parsing schedule: $e');
                print('[ScheduleList] Problem schedule data: $json');
                rethrow;
              }
            })
            .toList();
        _isLoading = false;
      });

      print('[ScheduleList] Successfully loaded ${_schedules.length} schedules');
      if (_schedules.isNotEmpty) {
        print('[ScheduleList] First schedule: ${_schedules[0].destinationName}');
      }
      print('[ScheduleList] ========================================');
    } catch (e, stackTrace) {
      print('[ScheduleList] ========================================');
      print('[ScheduleList] ERROR loading schedules: $e');
      print('[ScheduleList] Error type: ${e.runtimeType}');
      print('[ScheduleList] Stack trace: $stackTrace');
      print('[ScheduleList] ========================================');

      // Handle specific error types - show empty state for most errors
      // since backend might not be fully set up yet
      if (e is NotFoundException ||
          e is SocketException ||
          e is UnauthorizedException ||
          e is ServerException ||
          e is ApiException) {
        // Show empty state for API/network errors
        setState(() {
          _schedules = [];
          _isLoading = false;
        });

        // Only show notification for network errors
        if (e is SocketException && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('バックエンドサーバーに接続できません。サーバーが起動しているか確認してください。'),
              backgroundColor: AppColors.textSecondary,
              duration: const Duration(seconds: 3),
            ),
          );
        } else if (e is UnauthorizedException && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('認証エラー。再度ログインしてください。'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Show empty state for unexpected errors too
        setState(() {
          _schedules = [];
          _isLoading = false;
        });
      }
    }
  }

  /// Navigate to create schedule flow
  Future<void> _navigateToCreateSchedule() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateScheduleFlow(),
      ),
    );

    // Reload schedules when returning
    _loadSchedules();
  }

  /// Navigate to schedule edit flow
  Future<void> _navigateToEditSchedule(LocationSchedule schedule) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateScheduleFlow(existingSchedule: schedule),
      ),
    );

    // Reload schedules after returning from edit flow
    _loadSchedules();
  }

  /// Delete schedule
  Future<void> _deleteSchedule(LocationSchedule schedule) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('予定を削除'),
        content: Text('「${schedule.destinationName}」への予定を削除しますか?'),
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
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      print('[ScheduleList] Deleting schedule: ${schedule.id}');
      await _apiService.delete('/schedules/${schedule.id}');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('予定を削除しました'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Reload schedules
      _loadSchedules();
    } catch (e) {
      print('[ScheduleList] Error deleting schedule: $e');

      if (!mounted) return;

      String errorMessage = '予定の削除に失敗しました';
      if (e is SocketException) {
        errorMessage = 'バックエンドサーバーに接続できません';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Navigate to settings
  void _navigateToSettings() {
    // TODO: Implement settings screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('設定画面は準備中です')),
    );
  }

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

  /// Build custom header matching Figma design
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        children: [
          // Title row with settings button
          Row(
            children: [
              const SizedBox(width: 40), // Left spacer
              Expanded(
                child: Column(
                  children: [
                    // imane title
                    Text(
                      'imane',
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
                      '到着通知スケジュール',
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
              ),
              // Settings button
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      offset: Offset(0, 1),
                      blurRadius: 3,
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Color(0x1A000000),
                      offset: Offset(0, 1),
                      blurRadius: 2,
                      spreadRadius: -1,
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: _navigateToSettings,
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  padding: EdgeInsets.zero,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Create new schedule button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _navigateToCreateSchedule,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.black.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ).copyWith(
                elevation: MaterialStateProperty.all(4),
                shadowColor: MaterialStateProperty.all(
                  Colors.black.withOpacity(0.1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.add, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '新しい予定を作成',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.3125,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSchedules,
              child: const Text('再試行'),
            ),
          ],
        ),
      );
    }

    if (_schedules.isEmpty) {
      return Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          child: _buildEmptyState(),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSchedules,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _schedules.length,
        itemBuilder: (context, index) {
          final schedule = _schedules[index];
          return _ScheduleCard(
            schedule: schedule,
            onTap: () => _navigateToEditSchedule(schedule),
            onDelete: () => _deleteSchedule(schedule),
          );
        },
      ),
    );
  }

  /// Build empty state matching Figma design
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bell icon
            Icon(
              Icons.notifications_outlined,
              size: 48,
              color: AppColors.textSecondary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            // Main message
            Text(
              'まだ予定がありません',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
                letterSpacing: -0.3125,
              ),
            ),
            const SizedBox(height: 8),
            // Subtitle
            Text(
              '予定を作成して大切な人に自動通知',
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
    );
  }
}

/// Schedule card widget matching Figma design
class _ScheduleCard extends StatelessWidget {
  final LocationSchedule schedule;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ScheduleCard({
    required this.schedule,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
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
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(0, 1),
            blurRadius: 2,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date and time with primary background icon
          _buildInfoRow(
            label: '日時',
            text: _formatDateTime(schedule.startTime),
            icon: Icons.access_time,
            isPrimary: true,
          ),
          const SizedBox(height: 12),
          // Location with gray background icon
          _buildInfoRow(
            label: '目的地',
            text: '${schedule.destinationName} - ${schedule.destinationAddress}',
            icon: Icons.location_on,
            isPrimary: false,
          ),
          const SizedBox(height: 12),
          // Recipients with gray background icon
          _buildInfoRow(
            label: '通知先',
            text: _getRecipientNames(schedule.notifyToUsers),
            icon: Icons.people,
            isPrimary: false,
          ),
          const SizedBox(height: 8),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.edit,
                  label: '編集',
                  color: const Color(0xFF5A4A40),
                  onPressed: onTap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.delete,
                  label: '削除',
                  color: AppColors.primary,
                  onPressed: onDelete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String text,
    required IconData icon,
    required bool isPrimary,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Icon container
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isPrimary ? AppColors.primary : const Color(0xFFF5F5F5),
            shape: BoxShape.circle,
            boxShadow: isPrimary
                ? const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      offset: Offset(0, 4),
                      blurRadius: 6,
                      spreadRadius: -1,
                    ),
                    BoxShadow(
                      color: Color(0x1A000000),
                      offset: Offset(0, 2),
                      blurRadius: 4,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: isPrimary ? Colors.white : AppColors.textSecondary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        // Text content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF8B7969),
                ),
              ),
              Text(
                text,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF3D3D3D),
                  letterSpacing: -0.1504,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF5F5F5),
          foregroundColor: color,
          elevation: 0,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ).copyWith(
          elevation: MaterialStateProperty.all(2),
          shadowColor: MaterialStateProperty.all(
            const Color(0x1A000000),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.3125,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _getRecipientNames(List<dynamic> notifyToUsers) {
    if (notifyToUsers.isEmpty) return '通知先なし';

    // Import the NotifyToUser model at the top of the file
    final names = notifyToUsers.map((user) => user.displayName).toList();

    // Display all names separated by commas
    return names.join(', ');
  }
}
