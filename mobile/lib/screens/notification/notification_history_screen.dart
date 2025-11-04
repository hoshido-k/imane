import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/notification_history.dart';
import '../../services/api_service.dart';

/// Notification history screen (24 hours)
class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() =>
      _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  final ApiService _apiService = ApiService();
  List<NotificationHistory> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  /// Load notification history from API
  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.get('/notifications/history');
      final List<dynamic> notificationsJson =
          response['notifications'] ?? response;

      setState(() {
        _notifications = notificationsJson
            .map((json) => NotificationHistory.fromJson(json))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '通知履歴の読み込みに失敗しました: $e';
        _isLoading = false;
      });
    }
  }

  /// Open map link
  Future<void> _openMapLink(String? mapLink) async {
    if (mapLink == null || mapLink.isEmpty) return;

    final uri = Uri.parse(mapLink);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('地図を開けませんでした')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知履歴'),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('通知履歴について'),
                  content: const Text(
                    '過去24時間以内に送信された通知を表示しています。\n\n'
                    '24時間経過した通知は自動的に削除されます。',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('閉じる'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
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
              onPressed: _loadNotifications,
              child: const Text('再試行'),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_none, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              '通知履歴がありません',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'スケジュールを作成すると通知が表示されます',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return _NotificationCard(
            notification: notification,
            onMapTap: () => _openMapLink(notification.mapLink),
          );
        },
      ),
    );
  }
}

/// Notification card widget
class _NotificationCard extends StatelessWidget {
  final NotificationHistory notification;
  final VoidCallback onMapTap;

  const _NotificationCard({
    required this.notification,
    required this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Type and Time
            Row(
              children: [
                Text(
                  notification.type.icon,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.type.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatDateTime(notification.sentAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (notification.autoDeleteAt != null)
                  _buildTimeRemaining(notification.autoDeleteAt!),
              ],
            ),
            const SizedBox(height: 12),

            // From user
            if (notification.fromUserName != null)
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: notification.fromUserAvatar != null
                        ? NetworkImage(notification.fromUserAvatar!)
                        : null,
                    child: notification.fromUserAvatar == null
                        ? const Icon(Icons.person, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    notification.fromUserName!,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            if (notification.fromUserName != null) const SizedBox(height: 12),

            // Message
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                notification.message,
                style: const TextStyle(fontSize: 15),
              ),
            ),

            // Map link
            if (notification.mapLink != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onMapTap,
                icon: const Icon(Icons.map),
                label: const Text('地図を開く'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRemaining(DateTime autoDeleteAt) {
    final now = DateTime.now();
    final remaining = autoDeleteAt.difference(now);

    if (remaining.isNegative) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          '期限切れ',
          style: TextStyle(
            fontSize: 11,
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    String timeText;
    if (remaining.inHours > 0) {
      timeText = '${remaining.inHours}時間';
    } else if (remaining.inMinutes > 0) {
      timeText = '${remaining.inMinutes}分';
    } else {
      timeText = '${remaining.inSeconds}秒';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '残り$timeText',
        style: TextStyle(
          fontSize: 11,
          color: Colors.orange.shade700,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dateStr;
    if (date == today) {
      dateStr = '今日';
    } else if (date == today.subtract(const Duration(days: 1))) {
      dateStr = '昨日';
    } else {
      dateStr = '${dateTime.month}/${dateTime.day}';
    }

    return '$dateStr ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
