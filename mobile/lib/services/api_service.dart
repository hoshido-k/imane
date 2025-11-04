import 'dart:convert';
import 'package:http/http.dart' as http;

/// APIベースURL
/// TODO: 本番環境では環境変数から取得
class ApiConfig {
  // ローカル開発用（iOSシミュレーター）
  static const String baseUrl = 'http://localhost:8000/api/v1';

  // Android エミュレーター用の場合は以下を使用
  // static const String baseUrl = 'http://10.0.2.2:8000/api/v1';

  // 実機の場合はPCのIPアドレスを使用
  // static const String baseUrl = 'http://192.168.x.x:8000/api/v1';
}

/// API通信の基盤サービス
class ApiService {
  final String baseUrl;
  String? _accessToken;

  ApiService({String? baseUrl})
      : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  /// アクセストークンを設定
  void setAccessToken(String token) {
    _accessToken = token;
  }

  /// アクセストークンをクリア
  void clearAccessToken() {
    _accessToken = null;
  }

  /// 共通ヘッダーを取得
  Map<String, String> _getHeaders({bool includeAuth = true}) {
    final headers = {
      'Content-Type': 'application/json',
    };

    if (includeAuth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }

    return headers;
  }

  /// GETリクエスト
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool requiresAuth = true,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl$endpoint');

      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final response = await http.get(
        uri,
        headers: _getHeaders(includeAuth: requiresAuth),
      );

      return _handleResponse(response);
    } catch (e) {
      throw ApiException('GET request failed: $e');
    }
  }

  /// POSTリクエスト
  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(includeAuth: requiresAuth),
        body: body != null ? jsonEncode(body) : null,
      );

      return _handleResponse(response);
    } catch (e) {
      throw ApiException('POST request failed: $e');
    }
  }

  /// PUTリクエスト
  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(includeAuth: requiresAuth),
        body: body != null ? jsonEncode(body) : null,
      );

      return _handleResponse(response);
    } catch (e) {
      throw ApiException('PUT request failed: $e');
    }
  }

  /// PATCHリクエスト
  Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(includeAuth: requiresAuth),
        body: body != null ? jsonEncode(body) : null,
      );

      return _handleResponse(response);
    } catch (e) {
      throw ApiException('PATCH request failed: $e');
    }
  }

  /// DELETEリクエスト
  Future<dynamic> delete(
    String endpoint, {
    bool requiresAuth = true,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(includeAuth: requiresAuth),
      );

      return _handleResponse(response);
    } catch (e) {
      throw ApiException('DELETE request failed: $e');
    }
  }

  /// レスポンスを処理
  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;

    // 204 No Content の場合は空を返す
    if (statusCode == 204) {
      return null;
    }

    // レスポンスボディをデコード
    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (e) {
      // JSONでない場合はそのまま返す
      data = response.body;
    }

    // ステータスコードに応じた処理
    if (statusCode >= 200 && statusCode < 300) {
      return data;
    } else if (statusCode == 400) {
      final message = data is Map ? (data['detail'] ?? 'Bad Request') : 'Bad Request';
      throw BadRequestException(message);
    } else if (statusCode == 401) {
      final message = data is Map ? (data['detail'] ?? 'Unauthorized') : 'Unauthorized';
      throw UnauthorizedException(message);
    } else if (statusCode == 403) {
      final message = data is Map ? (data['detail'] ?? 'Forbidden') : 'Forbidden';
      throw ForbiddenException(message);
    } else if (statusCode == 404) {
      final message = data is Map ? (data['detail'] ?? 'Not Found') : 'Not Found';
      throw NotFoundException(message);
    } else if (statusCode >= 500) {
      final message = data is Map ? (data['detail'] ?? 'Server Error') : 'Server Error';
      throw ServerException(message);
    } else {
      throw ApiException('Unexpected status code: $statusCode');
    }
  }
}

/// API例外の基底クラス
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

/// 400 Bad Request
class BadRequestException extends ApiException {
  BadRequestException(super.message);
}

/// 401 Unauthorized
class UnauthorizedException extends ApiException {
  UnauthorizedException(super.message);
}

/// 403 Forbidden
class ForbiddenException extends ApiException {
  ForbiddenException(super.message);
}

/// 404 Not Found
class NotFoundException extends ApiException {
  NotFoundException(super.message);
}

/// 500 Server Error
class ServerException extends ApiException {
  ServerException(super.message);
}
