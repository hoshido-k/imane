import 'package:flutter/material.dart';
import '../../models/schedule.dart';
import '../../services/api_service.dart';
import '../../core/constants/app_colors.dart';
import 'create_schedule_screen.dart';
import 'schedule_detail_screen.dart';
import 'dart:io';

/// Schedule list screen (Home screen)
class ScheduleListScreen extends StatefulWidget {
  const ScheduleListScreen({super.key});

  @override
  State<ScheduleListScreen> createState() => _ScheduleListScreenState();
}

class _ScheduleListScreenState extends State<ScheduleListScreen> {
  final ApiService _apiService = ApiService();
  List<LocationSchedule> _schedules = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  /// Load schedules from API
  Future<void> _loadSchedules() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.get('/schedules');

      // Handle different response formats
      List<dynamic> schedulesJson;
      if (response is List) {
        schedulesJson = response;
      } else if (response is Map && response['schedules'] != null) {
        schedulesJson = response['schedules'];
      } else {
        schedulesJson = [];
      }

      setState(() {
        _schedules = schedulesJson
            .map((json) => LocationSchedule.fromJson(json))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print('[ScheduleList] Error loading schedules: $e');
      print('[ScheduleList] Error type: ${e.runtimeType}');

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
              content: const Text('バックエンドサーバーに接続できません'),
              backgroundColor: AppColors.textSecondary,
              duration: const Duration(seconds: 2),
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

  /// Navigate to create schedule screen
  Future<void> _navigateToCreateSchedule() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateScheduleScreen(),
      ),
    );

    if (result == true) {
      _loadSchedules();
    }
  }

  /// Navigate to schedule detail screen
  Future<void> _navigateToScheduleDetail(LocationSchedule schedule) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScheduleDetailScreen(schedule: schedule),
      ),
    );

    if (result == true) {
      _loadSchedules();
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
            onTap: () => _navigateToScheduleDetail(schedule),
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

/// Schedule card widget
class _ScheduleCard extends StatelessWidget {
  final LocationSchedule schedule;
  final VoidCallback onTap;

  const _ScheduleCard({
    required this.schedule,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Name and Status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      schedule.destinationName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusChip(schedule.status),
                ],
              ),
              const SizedBox(height: 8),

              // Address
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      schedule.destinationAddress,
                      style: const TextStyle(color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Time range
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${_formatDateTime(schedule.startTime)} 〜 ${_formatDateTime(schedule.endTime)}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Notification recipients
              Row(
                children: [
                  const Icon(Icons.people, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '通知先: ${schedule.notifyToUserIds.length}人',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),

              // Arrival time (if arrived)
              if (schedule.arrivedAt != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text(
                        '到着: ${_formatDateTime(schedule.arrivedAt!)}',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(ScheduleStatus status) {
    Color color;
    switch (status) {
      case ScheduleStatus.active:
        color = Colors.blue;
        break;
      case ScheduleStatus.arrived:
        color = Colors.green;
        break;
      case ScheduleStatus.completed:
        color = Colors.grey;
        break;
      case ScheduleStatus.expired:
        color = Colors.orange;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
