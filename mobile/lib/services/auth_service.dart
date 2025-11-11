import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// 認証サービス
class AuthService {
  final ApiService _apiService;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // SharedPreferencesのキー
  static const String _accessTokenKey = 'access_token';
  static const String _userIdKey = 'user_id';

  AuthService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// 新規登録
  Future<AuthResult> signup({
    required String username,
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      // バックエンドAPIで登録
      final response = await _apiService.post(
        '/auth/signup',
        body: {
          'username': username,
          'email': email,
          'password': password,
          'display_name': displayName,
        },
        requiresAuth: false,
      );

      final accessToken = response['access_token'];
      final uid = response['uid'];

      // トークンを保存
      await _saveToken(accessToken, uid);

      // APIServiceにトークンを設定
      _apiService.setAccessToken(accessToken);

      return AuthResult(
        success: true,
        accessToken: accessToken,
        uid: uid,
      );
    } on ApiException catch (e) {
      return AuthResult(
        success: false,
        errorMessage: e.message,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        errorMessage: '登録に失敗しました: $e',
      );
    }
  }

  /// ログイン（Firebase Auth + バックエンド）
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      print('[Auth] Attempting login with Firebase Auth for email: $email');

      // 1. Firebase Authenticationでログイン
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('[Auth] Firebase login successful, user: ${userCredential.user?.uid}');

      // 2. Firebase IDトークンを取得
      final idToken = await userCredential.user?.getIdToken();
      if (idToken == null) {
        throw Exception('Firebase IDトークンの取得に失敗しました');
      }

      // 3. バックエンドAPIでJWTトークンを取得
      final response = await _apiService.post(
        '/auth/login',
        body: {
          'id_token': idToken,
        },
        requiresAuth: false,
      );

      final accessToken = response['access_token'];
      final uid = response['uid'];

      // トークンを保存
      await _saveToken(accessToken, uid);

      // APIServiceにトークンを設定
      _apiService.setAccessToken(accessToken);

      return AuthResult(
        success: true,
        accessToken: accessToken,
        uid: uid,
      );
    } on FirebaseAuthException catch (e) {
      print('[Auth] FirebaseAuthException: code=${e.code}, message=${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'ユーザーが見つかりません';
          break;
        case 'wrong-password':
          errorMessage = 'パスワードが間違っています';
          break;
        case 'invalid-email':
          errorMessage = 'メールアドレスの形式が正しくありません';
          break;
        case 'user-disabled':
          errorMessage = 'このアカウントは無効化されています';
          break;
        case 'invalid-credential':
          errorMessage = 'メールアドレスまたはパスワードが正しくありません';
          break;
        default:
          errorMessage = 'ログインに失敗しました (${e.code}): ${e.message}';
      }

      return AuthResult(
        success: false,
        errorMessage: errorMessage,
      );
    } on ApiException catch (e) {
      print('[Auth] ApiException: ${e.message}');
      return AuthResult(
        success: false,
        errorMessage: e.message,
      );
    } catch (e) {
      print('[Auth] Unknown error: $e');
      return AuthResult(
        success: false,
        errorMessage: 'ログインに失敗しました: $e',
      );
    }
  }

  /// ログアウト
  Future<void> logout() async {
    try {
      // Firebase Authからログアウト
      await _firebaseAuth.signOut();

      // トークンをクリア
      await _clearToken();

      // APIServiceのトークンをクリア
      _apiService.clearAccessToken();
    } catch (e) {
      throw Exception('ログアウトに失敗しました: $e');
    }
  }

  /// アカウント削除
  Future<void> deleteAccount() async {
    try {
      // バックエンドAPIでユーザーデータを削除
      await _apiService.delete('/users/me');

      // Firebase Authからユーザーを削除
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.delete();
      }

      // トークンをクリア
      await _clearToken();

      // APIServiceのトークンをクリア
      _apiService.clearAccessToken();
    } catch (e) {
      throw Exception('アカウント削除に失敗しました: $e');
    }
  }

  /// パスワードリセットメールを送信
  Future<AuthResult> sendPasswordResetEmail({
    required String email,
  }) async {
    try {
      print('[Auth] Sending password reset email to: $email');
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      print('[Auth] Password reset email sent successfully');

      return AuthResult(
        success: true,
      );
    } on FirebaseAuthException catch (e) {
      print('[Auth] Password reset failed: code=${e.code}, message=${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'このメールアドレスは登録されていません';
          break;
        case 'invalid-email':
          errorMessage = 'メールアドレスの形式が正しくありません';
          break;
        default:
          errorMessage = 'パスワードリセットメールの送信に失敗しました (${e.code}): ${e.message}';
      }

      return AuthResult(
        success: false,
        errorMessage: errorMessage,
      );
    } catch (e) {
      print('[Auth] Password reset unknown error: $e');
      return AuthResult(
        success: false,
        errorMessage: 'パスワードリセットメールの送信に失敗しました: $e',
      );
    }
  }

  /// 保存されたトークンで自動ログイン
  Future<bool> autoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString(_accessTokenKey);
      final uid = prefs.getString(_userIdKey);

      if (accessToken == null || uid == null) {
        return false;
      }

      // トークンをAPIServiceに設定
      _apiService.setAccessToken(accessToken);

      // トークンの有効性を確認（/auth/meエンドポイントを叩く）
      try {
        await _apiService.get('/auth/me');
        return true;
      } catch (e) {
        // トークンが無効な場合はクリア
        await _clearToken();
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// 現在のユーザー情報を取得
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final response = await _apiService.get('/auth/me');
      return response;
    } on ApiException {
      return null;
    }
  }

  /// トークンを保存
  Future<void> _saveToken(String accessToken, String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_userIdKey, uid);
  }

  /// トークンをクリア
  Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_userIdKey);
  }

  /// ログイン状態を確認
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString(_accessTokenKey);
    return accessToken != null;
  }

  /// APIServiceを取得（他のサービスで使用）
  ApiService get apiService => _apiService;
}

/// 認証結果
class AuthResult {
  final bool success;
  final String? accessToken;
  final String? uid;
  final String? errorMessage;

  AuthResult({
    required this.success,
    this.accessToken,
    this.uid,
    this.errorMessage,
  });
}
