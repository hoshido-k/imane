/// Notify to user info
class NotifyToUser {
  final String userId;
  final String displayName;
  final String? avatarUrl;

  NotifyToUser({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
  });

  factory NotifyToUser.fromJson(Map<String, dynamic> json) {
    return NotifyToUser(
      userId: json['user_id'],
      displayName: json['display_name'],
      avatarUrl: json['avatar_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'display_name': displayName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
  }
}

/// Location Schedule model for imane
class LocationSchedule {
  final String? id;
  final String userId;
  final String destinationName;
  final String destinationAddress;
  final LatLng destinationCoords;
  final double geofenceRadius;
  final List<String> notifyToUserIds;
  final List<NotifyToUser> notifyToUsers;
  final DateTime startTime;
  final DateTime endTime;
  final String? recurrence;
  final bool notifyOnArrival;
  final int notifyAfterMinutes;
  final bool notifyOnDeparture;
  final ScheduleStatus status;
  final DateTime? arrivedAt;
  final DateTime? departedAt;
  final bool favorite;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  LocationSchedule({
    this.id,
    required this.userId,
    required this.destinationName,
    required this.destinationAddress,
    required this.destinationCoords,
    this.geofenceRadius = 50.0,
    required this.notifyToUserIds,
    this.notifyToUsers = const [],
    required this.startTime,
    required this.endTime,
    this.recurrence,
    this.notifyOnArrival = true,
    this.notifyAfterMinutes = 60,
    this.notifyOnDeparture = true,
    this.status = ScheduleStatus.active,
    this.arrivedAt,
    this.departedAt,
    this.favorite = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Create from JSON
  factory LocationSchedule.fromJson(Map<String, dynamic> json) {
    return LocationSchedule(
      id: json['id'],
      userId: json['user_id'],
      destinationName: json['destination_name'],
      destinationAddress: json['destination_address'],
      destinationCoords: LatLng(
        json['destination_coords']['lat'],
        json['destination_coords']['lng'],
      ),
      geofenceRadius: (json['geofence_radius'] ?? 50.0).toDouble(),
      notifyToUserIds: List<String>.from(json['notify_to_user_ids'] ?? []),
      notifyToUsers: json['notify_to_users'] != null
          ? (json['notify_to_users'] as List)
              .map((user) => NotifyToUser.fromJson(user))
              .toList()
          : [],
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      recurrence: json['recurrence'],
      notifyOnArrival: json['notify_on_arrival'] ?? true,
      notifyAfterMinutes: json['notify_after_minutes'] ?? 60,
      notifyOnDeparture: json['notify_on_departure'] ?? true,
      status: ScheduleStatus.fromString(json['status']),
      arrivedAt: json['arrived_at'] != null
          ? DateTime.parse(json['arrived_at'])
          : null,
      departedAt: json['departed_at'] != null
          ? DateTime.parse(json['departed_at'])
          : null,
      favorite: json['favorite'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'destination_name': destinationName,
      'destination_address': destinationAddress,
      'destination_coords': {
        'lat': destinationCoords.latitude,
        'lng': destinationCoords.longitude,
      },
      'geofence_radius': geofenceRadius,
      'notify_to_user_ids': notifyToUserIds,
      'notify_to_users': notifyToUsers.map((user) => user.toJson()).toList(),
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      if (recurrence != null) 'recurrence': recurrence,
      'notify_on_arrival': notifyOnArrival,
      'notify_after_minutes': notifyAfterMinutes,
      'notify_on_departure': notifyOnDeparture,
      'status': status.value,
      if (arrivedAt != null) 'arrived_at': arrivedAt!.toIso8601String(),
      if (departedAt != null) 'departed_at': departedAt!.toIso8601String(),
      'favorite': favorite,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  /// Copy with
  LocationSchedule copyWith({
    String? id,
    String? userId,
    String? destinationName,
    String? destinationAddress,
    LatLng? destinationCoords,
    double? geofenceRadius,
    List<String>? notifyToUserIds,
    List<NotifyToUser>? notifyToUsers,
    DateTime? startTime,
    DateTime? endTime,
    String? recurrence,
    bool? notifyOnArrival,
    int? notifyAfterMinutes,
    bool? notifyOnDeparture,
    ScheduleStatus? status,
    DateTime? arrivedAt,
    DateTime? departedAt,
    bool? favorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LocationSchedule(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      destinationName: destinationName ?? this.destinationName,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      destinationCoords: destinationCoords ?? this.destinationCoords,
      geofenceRadius: geofenceRadius ?? this.geofenceRadius,
      notifyToUserIds: notifyToUserIds ?? this.notifyToUserIds,
      notifyToUsers: notifyToUsers ?? this.notifyToUsers,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      recurrence: recurrence ?? this.recurrence,
      notifyOnArrival: notifyOnArrival ?? this.notifyOnArrival,
      notifyAfterMinutes: notifyAfterMinutes ?? this.notifyAfterMinutes,
      notifyOnDeparture: notifyOnDeparture ?? this.notifyOnDeparture,
      status: status ?? this.status,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      departedAt: departedAt ?? this.departedAt,
      favorite: favorite ?? this.favorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Schedule status enum
enum ScheduleStatus {
  active('active'),
  arrived('arrived'),
  completed('completed'),
  expired('expired');

  final String value;
  const ScheduleStatus(this.value);

  static ScheduleStatus fromString(String value) {
    return ScheduleStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => ScheduleStatus.active,
    );
  }

  String get displayName {
    switch (this) {
      case ScheduleStatus.active:
        return 'アクティブ';
      case ScheduleStatus.arrived:
        return '到着済み';
      case ScheduleStatus.completed:
        return '完了';
      case ScheduleStatus.expired:
        return '期限切れ';
    }
  }
}

/// Latitude and Longitude
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  Map<String, dynamic> toJson() {
    return {
      'lat': latitude,
      'lng': longitude,
    };
  }

  @override
  String toString() => 'LatLng($latitude, $longitude)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LatLng &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}
