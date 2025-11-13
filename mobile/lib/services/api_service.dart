import 'dart:convert';
import 'package:http/http.dart' as http;

/// APIベースURL
/// Flutter起動時の --dart-define で環境を指定します
///
/// 使用例:
/// - 開発環境: flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1 --dart-define=ENVIRONMENT=development
/// - 本番環境: flutter build ios --dart-define=API_BASE_URL=https://api.imane.app/api/v1 --dart-define=ENVIRONMENT=production
class ApiConfig {
  // Flutter起動時の --dart-define で設定
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.0.14:8000/api/v1', // デフォルトは開発環境（実機用）
  );

  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';

  // ローカル開発用の定数（参考用）
  static const String localSimulator = 'http://localhost:8000/api/v1';
  static const String localDevice = 'http://192.168.0.14:8000/api/v1';
  static const String androidEmulator = 'http://10.0.2.2:8000/api/v1';
}

/// API通信の基盤サービス
class ApiService {
  final String baseUrl;
  String? _accessToken;
  late final http.Client _client;

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();

  factory ApiService({String? baseUrl}) {
    return _instance;
  }

  ApiService._internal({String? baseUrl})
      : baseUrl = baseUrl ?? ApiConfig.baseUrl {
    // リダイレクトを自動で追従するHTTPクライアントを作成
    _client = http.Client();

    // 開発環境でのみ環境情報をログ出力
    if (ApiConfig.isDevelopment) {
      print('[ApiService] Environment: ${ApiConfig.environment}');
      print('[ApiService] Base URL: ${this.baseUrl}');
    }
  }

  /// アクセストークンを設定
  void setAccessToken(String token) {
    _accessToken = token;
  }

  /// アクセストークンをクリア
  void clearAccessToken() {
    _accessToken = null;
  }

  /// アクセストークンを取得
  String? get accessToken => _accessToken;

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

      print('[ApiService] GET $uri');
      print('[ApiService] Auth required: $requiresAuth');
      print('[ApiService] Has token: ${_accessToken != null}');

      final response = await _client.get(
        uri,
        headers: _getHeaders(includeAuth: requiresAuth),
      );

      print('[ApiService] Response status: ${response.statusCode}');
      print('[ApiService] Response body: ${response.body}');

      return _handleResponse(response);
    } catch (e) {
      print('[ApiService] GET request error: $e');
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
      print('[ApiService] POST $baseUrl$endpoint');
      print('[ApiService] Auth required: $requiresAuth');
      print('[ApiService] Has token: ${_accessToken != null}');
      if (body != null) {
        print('[ApiService] Request body: ${jsonEncode(body)}');
      }

      final response = await _client.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(includeAuth: requiresAuth),
        body: body != null ? jsonEncode(body) : null,
      );

      print('[ApiService] Response status: ${response.statusCode}');
      print('[ApiService] Response body: ${response.body}');

      return _handleResponse(response);
    } catch (e) {
      print('[ApiService] POST request error: $e');
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
      final response = await _client.put(
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
      final response = await _client.patch(
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
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      print('[ApiService] DELETE $baseUrl$endpoint');
      print('[ApiService] Auth required: $requiresAuth');
      print('[ApiService] Has token: ${_accessToken != null}');
      if (body != null) {
        print('[ApiService] Request body: ${jsonEncode(body)}');
      }

      final response = await _client.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(includeAuth: requiresAuth),
        body: body != null ? jsonEncode(body) : null,
      );

      print('[ApiService] Response status: ${response.statusCode}');
      print('[ApiService] Response body: ${response.body}');

      return _handleResponse(response);
    } catch (e) {
      print('[ApiService] DELETE request error: $e');
      throw ApiException('DELETE request failed: $e');
    }
  }

  /// 位置情報を更新
  /// POST /location/update
  Future<dynamic> updateLocation({
    required double latitude,
    required double longitude,
    double? accuracy,
  }) async {
    return await post(
      '/location/update',
      body: {
        'coords': {
          'lat': latitude,
          'lng': longitude,
        },
        if (accuracy != null) 'accuracy': accuracy,
      },
      requiresAuth: true,
    );
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
