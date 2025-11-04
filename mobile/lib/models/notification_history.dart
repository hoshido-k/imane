/// Notification History model for imane
class NotificationHistory {
  final String? id;
  final String fromUserId;
  final String toUserId;
  final String scheduleId;
  final NotificationType type;
  final String message;
  final String? mapLink;
  final DateTime sentAt;
  final DateTime? autoDeleteAt;

  // Optional user info for display
  final String? fromUserName;
  final String? fromUserAvatar;

  NotificationHistory({
    this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.scheduleId,
    required this.type,
    required this.message,
    this.mapLink,
    required this.sentAt,
    this.autoDeleteAt,
    this.fromUserName,
    this.fromUserAvatar,
  });

  /// Create from JSON
  factory NotificationHistory.fromJson(Map<String, dynamic> json) {
    return NotificationHistory(
      id: json['id'],
      fromUserId: json['from_user_id'],
      toUserId: json['to_user_id'],
      scheduleId: json['schedule_id'],
      type: NotificationType.fromString(json['type']),
      message: json['message'],
      mapLink: json['map_link'],
      sentAt: DateTime.parse(json['sent_at']),
      autoDeleteAt: json['auto_delete_at'] != null
          ? DateTime.parse(json['auto_delete_at'])
          : null,
      fromUserName: json['from_user_name'],
      fromUserAvatar: json['from_user_avatar'],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'schedule_id': scheduleId,
      'type': type.value,
      'message': message,
      if (mapLink != null) 'map_link': mapLink,
      'sent_at': sentAt.toIso8601String(),
      if (autoDeleteAt != null) 'auto_delete_at': autoDeleteAt!.toIso8601String(),
      if (fromUserName != null) 'from_user_name': fromUserName,
      if (fromUserAvatar != null) 'from_user_avatar': fromUserAvatar,
    };
  }

  /// Copy with
  NotificationHistory copyWith({
    String? id,
    String? fromUserId,
    String? toUserId,
    String? scheduleId,
    NotificationType? type,
    String? message,
    String? mapLink,
    DateTime? sentAt,
    DateTime? autoDeleteAt,
    String? fromUserName,
    String? fromUserAvatar,
  }) {
    return NotificationHistory(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      scheduleId: scheduleId ?? this.scheduleId,
      type: type ?? this.type,
      message: message ?? this.message,
      mapLink: mapLink ?? this.mapLink,
      sentAt: sentAt ?? this.sentAt,
      autoDeleteAt: autoDeleteAt ?? this.autoDeleteAt,
      fromUserName: fromUserName ?? this.fromUserName,
      fromUserAvatar: fromUserAvatar ?? this.fromUserAvatar,
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
