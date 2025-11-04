import 'schedule.dart';

/// Favorite Location model for imane
class FavoriteLocation {
  final String? id;
  final String userId;
  final String name;
  final String address;
  final LatLng coords;
  final DateTime? createdAt;

  FavoriteLocation({
    this.id,
    required this.userId,
    required this.name,
    required this.address,
    required this.coords,
    this.createdAt,
  });

  /// Create from JSON
  factory FavoriteLocation.fromJson(Map<String, dynamic> json) {
    return FavoriteLocation(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      address: json['address'],
      coords: LatLng(
        json['coords']['lat'],
        json['coords']['lng'],
      ),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'name': name,
      'address': address,
      'coords': {
        'lat': coords.latitude,
        'lng': coords.longitude,
      },
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// Copy with
  FavoriteLocation copyWith({
    String? id,
    String? userId,
    String? name,
    String? address,
    LatLng? coords,
    DateTime? createdAt,
  }) {
    return FavoriteLocation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      address: address ?? this.address,
      coords: coords ?? this.coords,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
