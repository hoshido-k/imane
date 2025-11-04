import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import '../../models/schedule.dart';
import '../../services/api_service.dart';

/// Schedule detail screen
class ScheduleDetailScreen extends StatefulWidget {
  final LocationSchedule schedule;

  const ScheduleDetailScreen({
    super.key,
    required this.schedule,
  });

  @override
  State<ScheduleDetailScreen> createState() => _ScheduleDetailScreenState();
}

class _ScheduleDetailScreenState extends State<ScheduleDetailScreen> {
  final ApiService _apiService = ApiService();
  late LocationSchedule _schedule;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _schedule = widget.schedule;
  }

  /// Refresh schedule data
  Future<void> _refreshSchedule() async {
    if (_schedule.id == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.get('/schedules/${_schedule.id}');
      setState(() {
        _schedule = LocationSchedule.fromJson(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新に失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_schedule.destinationName),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshSchedule,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshSchedule,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Map
                    SizedBox(
                      height: 250,
                      child: gmap.GoogleMap(
                        initialCameraPosition: gmap.CameraPosition(
                          target: gmap.LatLng(
                            _schedule.destinationCoords.latitude,
                            _schedule.destinationCoords.longitude,
                          ),
                          zoom: 15,
                        ),
                        markers: {
                          gmap.Marker(
                            markerId: const gmap.MarkerId('destination'),
                            position: gmap.LatLng(
                              _schedule.destinationCoords.latitude,
                              _schedule.destinationCoords.longitude,
                            ),
                            infoWindow: gmap.InfoWindow(
                              title: _schedule.destinationName,
                            ),
                          ),
                        },
                        circles: {
                          gmap.Circle(
                            circleId: const gmap.CircleId('geofence'),
                            center: gmap.LatLng(
                              _schedule.destinationCoords.latitude,
                              _schedule.destinationCoords.longitude,
                            ),
                            radius: _schedule.geofenceRadius,
                            fillColor: Colors.blue.withOpacity(0.2),
                            strokeColor: Colors.blue,
                            strokeWidth: 2,
                          ),
                        },
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status
                          _buildStatusSection(),
                          const SizedBox(height: 24),

                          // Basic info
                          _buildInfoSection(),
                          const SizedBox(height: 24),

                          // Time info
                          _buildTimeSection(),
                          const SizedBox(height: 24),

                          // Notification settings
                          _buildNotificationSection(),
                          const SizedBox(height: 24),

                          // Recipients
                          _buildRecipientsSection(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusSection() {
    Color statusColor;
    IconData statusIcon;

    switch (_schedule.status) {
      case ScheduleStatus.active:
        statusColor = Colors.blue;
        statusIcon = Icons.directions_run;
        break;
      case ScheduleStatus.arrived:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case ScheduleStatus.completed:
        statusColor = Colors.grey;
        statusIcon = Icons.done_all;
        break;
      case ScheduleStatus.expired:
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
        break;
    }

    return Card(
      color: statusColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(statusIcon, size: 32, color: statusColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _schedule.status.displayName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  if (_schedule.arrivedAt != null)
                    Text(
                      '到着: ${_formatDateTime(_schedule.arrivedAt!)}',
                      style: TextStyle(color: statusColor),
                    ),
                  if (_schedule.departedAt != null)
                    Text(
                      '退出: ${_formatDateTime(_schedule.departedAt!)}',
                      style: TextStyle(color: statusColor),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '目的地情報',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.place, '名前', _schedule.destinationName),
        _buildInfoRow(Icons.location_on, '住所', _schedule.destinationAddress),
        _buildInfoRow(
          Icons.my_location,
          '検知範囲',
          '${_schedule.geofenceRadius.toInt()}m',
        ),
      ],
    );
  }

  Widget _buildTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '時間設定',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.access_time, '開始', _formatDateTime(_schedule.startTime)),
        _buildInfoRow(Icons.access_time, '終了', _formatDateTime(_schedule.endTime)),
        if (_schedule.recurrence != null)
          _buildInfoRow(Icons.repeat, '繰り返し', _schedule.recurrence!),
      ],
    );
  }

  Widget _buildNotificationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '通知設定',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildNotificationRow(
          '到着通知',
          _schedule.notifyOnArrival,
          '目的地に到着したとき',
        ),
        _buildNotificationRow(
          '滞在通知',
          _schedule.notifyAfterMinutes > 0,
          '到着から${_schedule.notifyAfterMinutes}分後',
        ),
        _buildNotificationRow(
          '退出通知',
          _schedule.notifyOnDeparture,
          '目的地から出発したとき',
        ),
      ],
    );
  }

  Widget _buildRecipientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '通知先',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.people),
            title: Text('${_schedule.notifyToUserIds.length}人'),
            subtitle: const Text('タップして詳細を表示'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Show recipients list
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('通知先一覧は実装中です')),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationRow(String title, bool enabled, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.check_circle : Icons.cancel,
            color: enabled ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
