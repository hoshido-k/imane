import 'package:flutter/material.dart';
import '../../models/schedule.dart';
import '../../services/api_service.dart';
import '../../core/constants/app_colors.dart';
import 'create_schedule_flow.dart';
import '../notification/notification_history_screen.dart';
import 'dart:io';

/// Schedule list screen (Home screen)
class ScheduleListScreen extends StatefulWidget {
  const ScheduleListScreen({super.key});

  @override
  State<ScheduleListScreen> createState() => _ScheduleListScreenState();
}

class _ScheduleListScreenState extends State<ScheduleListScreen> with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  List<LocationSchedule> _mySchedules = [];
  List<LocationSchedule> _friendSchedules = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _currentTabIndex = 0; // 0: My Schedules, 1: Friend Schedules

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
      // Load my schedules
      print('[ScheduleList] Making GET request to /schedules...');
      final myResponse = await _apiService.get('/schedules');
      print('[ScheduleList] My schedules response: $myResponse');

      List<dynamic> mySchedulesJson = [];
      if (myResponse is List) {
        mySchedulesJson = myResponse;
      } else if (myResponse is Map && myResponse['schedules'] != null) {
        mySchedulesJson = myResponse['schedules'];
      }

      // Load friend schedules
      print('[ScheduleList] Making GET request to /schedules/friend-schedules...');
      final friendResponse = await _apiService.get('/schedules/friend-schedules');
      print('[ScheduleList] Friend schedules response: $friendResponse');

      List<dynamic> friendSchedulesJson = [];
      if (friendResponse is List) {
        friendSchedulesJson = friendResponse;
      } else if (friendResponse is Map && friendResponse['schedules'] != null) {
        friendSchedulesJson = friendResponse['schedules'];
      }

      setState(() {
        _mySchedules = mySchedulesJson
            .map((json) {
              try {
                return LocationSchedule.fromJson(json);
              } catch (e) {
                print('[ScheduleList] Error parsing my schedule: $e');
                print('[ScheduleList] Problem schedule data: $json');
                rethrow;
              }
            })
            .toList();

        _friendSchedules = friendSchedulesJson
            .map((json) {
              try {
                return LocationSchedule.fromJson(json);
              } catch (e) {
                print('[ScheduleList] Error parsing friend schedule: $e');
                print('[ScheduleList] Problem schedule data: $json');
                rethrow;
              }
            })
            .toList();

        _isLoading = false;
      });

      print('[ScheduleList] Successfully loaded ${_mySchedules.length} my schedules');
      print('[ScheduleList] Successfully loaded ${_friendSchedules.length} friend schedules');
      print('[ScheduleList] ========================================');
    } catch (e, stackTrace) {
      print('[ScheduleList] ========================================');
      print('[ScheduleList] ERROR loading schedules: $e');
      print('[ScheduleList] Error type: ${e.runtimeType}');
      print('[ScheduleList] Stack trace: $stackTrace');
      print('[ScheduleList] ========================================');

      // Handle specific error types - show empty state for most errors
      setState(() {
        _mySchedules = [];
        _friendSchedules = [];
        _isLoading = false;
      });
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

      // Reload schedules
      _loadSchedules();
    } catch (e) {
      print('[ScheduleList] Error deleting schedule: $e');
      // Error is handled silently - user can retry if needed
    }
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
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        children: [
          const SizedBox(width: 40), // Left spacer for symmetry
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
          // 通知履歴ボタン
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  offset: Offset(0, 2),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                Icons.notifications_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationHistoryScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Tab bar
        _buildTabBar(),
        // Create new schedule button (only show for "My Schedules" tab)
        if (_currentTabIndex == 0) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _navigateToCreateSchedule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, // Primary color
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
          ),
        ],
        const SizedBox(height: 16),
        // Content
        Expanded(child: _buildTabContent()),
      ],
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _currentTabIndex = 0;
                  });
                },
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: _currentTabIndex == 0
                        ? Colors.white // Selected: White
                        : const Color(0xFFB0B0B0), // Unselected: Gray
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '自分が作成',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: _currentTabIndex == 0
                          ? AppColors.textPrimary
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _currentTabIndex = 1;
                  });
                },
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: _currentTabIndex == 1
                        ? Colors.white // Selected: White
                        : const Color(0xFFB0B0B0), // Unselected: Gray
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'フレンドが作成',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: _currentTabIndex == 1
                          ? AppColors.textPrimary
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
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

    final schedules = _currentTabIndex == 0 ? _mySchedules : _friendSchedules;

    if (schedules.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadSchedules,
        color: AppColors.primary,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: _buildEmptyState(),
                ),
              ),
            );
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSchedules,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: schedules.length,
        itemBuilder: (context, index) {
          final schedule = schedules[index];
          return _ScheduleCard(
            schedule: schedule,
            onTap: _currentTabIndex == 0 ? () => _navigateToEditSchedule(schedule) : null,
            onDelete: _currentTabIndex == 0 ? () => _deleteSchedule(schedule) : null,
            showCreator: _currentTabIndex == 1,
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
            // Schedule icon
            Icon(
              Icons.event_outlined,
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
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showCreator;

  const _ScheduleCard({
    required this.schedule,
    this.onTap,
    this.onDelete,
    this.showCreator = false,
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
          // Status badge in upper right corner
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildStatusBadge(schedule.status),
            ],
          ),
          const SizedBox(height: 12),
          // Show creator if this is a friend's schedule
          if (showCreator && schedule.creator != null) ...[
            _buildInfoRow(
              label: '作成者',
              text: schedule.creator!.displayName,
              icon: Icons.person,
              isPrimary: true,
            ),
            const SizedBox(height: 12),
          ],
          // Date and time with primary background icon
          _buildInfoRow(
            label: '日時',
            text: _formatDateTime(schedule.startTime),
            icon: Icons.access_time,
            isPrimary: !showCreator,
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
          // Action buttons (only for my schedules)
          if (onTap != null && onDelete != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.edit,
                    label: '編集',
                    color: const Color(0xFF5A4A40),
                    onPressed: onTap!,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.delete,
                    label: '削除',
                    color: AppColors.primary,
                    onPressed: onDelete!,
                  ),
                ),
              ],
            ),
          ],
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

  String _getRecipientNames(List<NotifyToUser> notifyToUsers) {
    if (notifyToUsers.isEmpty) return '通知先なし';

    // Display all names separated by commas
    final names = notifyToUsers.map((user) => user.displayName).toList();
    return names.join(', ');
  }

  /// Build status badge
  Widget _buildStatusBadge(ScheduleStatus status) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case ScheduleStatus.active:
        backgroundColor = const Color(0xFFE3F2FD); // Light blue
        textColor = const Color(0xFF1976D2); // Blue
        icon = Icons.check_circle_outline;
        break;
      case ScheduleStatus.arrived:
        backgroundColor = const Color(0xFFFFF3E0); // Light orange
        textColor = const Color(0xFFF57C00); // Orange
        icon = Icons.location_on;
        break;
      case ScheduleStatus.completed:
        backgroundColor = const Color(0xFFE8F5E9); // Light green
        textColor = const Color(0xFF388E3C); // Green
        icon = Icons.check_circle;
        break;
      case ScheduleStatus.expired:
        backgroundColor = const Color(0xFFEEEEEE); // Light gray
        textColor = const Color(0xFF757575); // Gray
        icon = Icons.schedule;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            status.displayName,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
