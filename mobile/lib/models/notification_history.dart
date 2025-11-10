/// Notification History model for imane
class NotificationHistory {
  final String notificationId;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;

  // Computed properties from data
  String? get mapLink => data['map_link'] as String?;
  String? get fromUserId => data['from_user_id'] as String?;
  String? get scheduleId => data['schedule_id'] as String?;
  String? get destinationName => data['destination_name'] as String?;

  NotificationHistory({
    required this.notificationId,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.isRead,
    required this.createdAt,
    this.readAt,
  });

  /// Create from JSON
  factory NotificationHistory.fromJson(Map<String, dynamic> json) {
    return NotificationHistory(
      notificationId: json['notification_id'] as String,
      userId: json['user_id'] as String,
      type: NotificationType.fromString(json['type'] as String),
      title: json['title'] as String,
      body: json['body'] as String,
      data: json['data'] as Map<String, dynamic>? ?? {},
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'notification_id': notificationId,
      'user_id': userId,
      'type': type.value,
      'title': title,
      'body': body,
      'data': data,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      if (readAt != null) 'read_at': readAt!.toIso8601String(),
    };
  }

  /// Copy with
  NotificationHistory copyWith({
    String? notificationId,
    String? userId,
    NotificationType? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
    DateTime? readAt,
  }) {
    return NotificationHistory(
      notificationId: notificationId ?? this.notificationId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
    );
  }
}

/// Notification type enum
enum NotificationType {
  arrival('arrival'),
  stay('stay'),
  departure('departure');

  final String value;
  const NotificationType(this.value);

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => NotificationType.arrival,
    );
  }

  String get displayName {
    switch (this) {
      case NotificationType.arrival:
        return '到着';
      case NotificationType.stay:
        return '滞在';
      case NotificationType.departure:
        return '退出';
    }
  }

  String get icon {
    switch (this) {
      case NotificationType.arrival:
        return '📍';
      case NotificationType.stay:
        return '⏱️';
      case NotificationType.departure:
        return '🚶';
    }
  }
}
