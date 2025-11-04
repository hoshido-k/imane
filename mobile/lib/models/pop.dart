import 'package:google_maps_flutter/google_maps_flutter.dart';

enum PopCategory {
  all,
  cafe,
  gourmet,
  entertainment,
  sports,
  gaming,
  study,
  other,
}

extension PopCategoryExtension on PopCategory {
  String get displayName {
    switch (this) {
      case PopCategory.all:
        return 'すべて';
      case PopCategory.cafe:
        return 'カフェ';
      case PopCategory.gourmet:
        return 'グルメ';
      case PopCategory.entertainment:
        return 'エンタメ';
      case PopCategory.sports:
        return 'スポーツ';
      case PopCategory.gaming:
        return 'ゲーム';
      case PopCategory.study:
        return '作業・勉強';
      case PopCategory.other:
        return 'その他';
    }
  }

  String get emoji {
    switch (this) {
      case PopCategory.all:
        return '🌟';
      case PopCategory.cafe:
        return '☕';
      case PopCategory.gourmet:
        return '🍜';
      case PopCategory.entertainment:
        return '🎬';
      case PopCategory.sports:
        return '🏃';
      case PopCategory.gaming:
        return '🎮';
      case PopCategory.study:
        return '📚';
      case PopCategory.other:
        return '✨';
    }
  }

  int get color {
    switch (this) {
      case PopCategory.all:
        return 0xFF8B5CF6; // Purple
      case PopCategory.cafe:
        return 0xFF92400E; // Brown
      case PopCategory.gourmet:
        return 0xFFEA580C; // Orange/Red
      case PopCategory.entertainment:
        return 0xFF7C3AED; // Purple
      case PopCategory.sports:
        return 0xFF059669; // Green
      case PopCategory.gaming:
        return 0xFF5B21B6; // Deep Purple
      case PopCategory.study:
        return 0xFF10B981; // Light Green
      case PopCategory.other:
        return 0xFF6EE7B7; // Very Light Green
    }
  }
}

class Pop {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String message;
  final PopCategory category;
  final LatLng location;
  final String? locationName;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;

  Pop({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.message,
    required this.category,
    required this.location,
    this.locationName,
    required this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
  });

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}時間';
    } else {
      return '${difference.inDays}日';
    }
  }
}
