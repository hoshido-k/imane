import 'package:flutter/material.dart';
import '../../models/schedule.dart';
import '../../services/api_service.dart';
import 'create_schedule_screen.dart';
import 'schedule_detail_screen.dart';

/// Schedule list screen
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
      final List<dynamic> schedulesJson = response['schedules'] ?? response;

      setState(() {
        _schedules = schedulesJson
            .map((json) => LocationSchedule.fromJson(json))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'スケジュールの読み込みに失敗しました: $e';
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('スケジュール'),
        backgroundColor: Colors.blue,
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateSchedule,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'スケジュールがありません',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              '右下の＋ボタンから作成できます',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSchedules,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
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
