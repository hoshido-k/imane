import 'api_service.dart';

/// フレンド関連のAPIサービス
class FriendService {
  final ApiService _apiService;

  FriendService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// ユーザーを検索
  /// GET /users/search?q={query}
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final response = await _apiService.get(
        '/users/search',
        queryParams: {'q': query},
      );

      if (response is List) {
        return List<Map<String, dynamic>>.from(
          response.map((item) => Map<String, dynamic>.from(item)),
        );
      }
      return [];
    } catch (e) {
      print('[FriendService] searchUsers error: $e');
      rethrow;
    }
  }

  /// フレンドリクエストを送信
  /// POST /friends/requests
  Future<Map<String, dynamic>> sendFriendRequest({
    required String toUserId,
    String? message,
  }) async {
    try {
      final response = await _apiService.post(
        '/friends/requests',
        body: {
          'to_user_id': toUserId,
          if (message != null) 'message': message,
        },
      );

      return Map<String, dynamic>.from(response);
    } catch (e) {
      print('[FriendService] sendFriendRequest error: $e');
      rethrow;
    }
  }

  /// 受信したフレンドリクエスト一覧を取得
  /// GET /friends/requests/received
  Future<List<Map<String, dynamic>>> getReceivedRequests() async {
    try {
      final response = await _apiService.get('/friends/requests/received');

      if (response is Map && response.containsKey('requests')) {
        return List<Map<String, dynamic>>.from(
          (response['requests'] as List)
              .map((item) => Map<String, dynamic>.from(item)),
        );
      }
      return [];
    } catch (e) {
      print('[FriendService] getReceivedRequests error: $e');
      rethrow;
    }
  }

  /// 送信したフレンドリクエスト一覧を取得
  /// GET /friends/requests/sent
  Future<List<Map<String, dynamic>>> getSentRequests() async {
    try {
      final response = await _apiService.get('/friends/requests/sent');

      if (response is Map && response.containsKey('requests')) {
        return List<Map<String, dynamic>>.from(
          (response['requests'] as List)
              .map((item) => Map<String, dynamic>.from(item)),
        );
      }
      return [];
    } catch (e) {
      print('[FriendService] getSentRequests error: $e');
      rethrow;
    }
  }

  /// フレンドリクエストを承認
  /// POST /friends/requests/{request_id}/accept
  Future<Map<String, dynamic>> acceptFriendRequest(String requestId) async {
    try {
      final response = await _apiService.post(
        '/friends/requests/$requestId/accept',
      );

      return Map<String, dynamic>.from(response);
    } catch (e) {
      print('[FriendService] acceptFriendRequest error: $e');
      rethrow;
    }
  }

  /// フレンドリクエストを拒否
  /// POST /friends/requests/{request_id}/reject
  Future<Map<String, dynamic>> rejectFriendRequest(String requestId) async {
    try {
      final response = await _apiService.post(
        '/friends/requests/$requestId/reject',
      );

      return Map<String, dynamic>.from(response);
    } catch (e) {
      print('[FriendService] rejectFriendRequest error: $e');
      rethrow;
    }
  }

  /// フレンド一覧を取得
  /// GET /friends
  Future<List<Map<String, dynamic>>> getFriends() async {
    try {
      final response = await _apiService.get('/friends');

      if (response is Map && response.containsKey('friends')) {
        return List<Map<String, dynamic>>.from(
          (response['friends'] as List)
              .map((item) => Map<String, dynamic>.from(item)),
        );
      }
      return [];
    } catch (e) {
      print('[FriendService] getFriends error: $e');
      rethrow;
    }
  }

  /// フレンドを削除
  /// DELETE /friends/{friend_id}
  Future<void> removeFriend(String friendId) async {
    try {
      await _apiService.delete('/friends/$friendId');
    } catch (e) {
      print('[FriendService] removeFriend error: $e');
      rethrow;
    }
  }
}
