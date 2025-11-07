import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();

  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  int _currentStep = 0; // 0=ステップ1, 1=ステップ2

  // Username重複チェック用
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable; // null=未チェック, true=利用可能, false=既に使用されている
  Timer? _usernameCheckTimer;

  // Email重複チェック用
  bool _isCheckingEmail = false;
  bool? _isEmailAvailable; // null=未チェック, true=利用可能, false=既に使用されている
  Timer? _emailCheckTimer;

  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameCheckTimer?.cancel();
    _emailCheckTimer?.cancel();
    super.dispose();
  }

  bool get _isStep1Valid {
    final displayName = _displayNameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();

    return displayName.isNotEmpty &&
           username.isNotEmpty &&
           username.length >= 3 &&
           RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username) &&
           _isUsernameAvailable == true && // 重複チェックOKの場合のみ
           email.isNotEmpty &&
           email.contains('@') &&
           _isEmailAvailable == true; // メール重複チェックOKの場合のみ
  }

  bool get _isStep2Valid {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    return password.isNotEmpty &&
           password.length >= 8 &&
           confirmPassword.isNotEmpty &&
           password == confirmPassword;
  }

  /// Username重複チェック（デバウンス処理付き）
  void _checkUsernameAvailability(String username) {
    // タイマーをキャンセル
    _usernameCheckTimer?.cancel();

    // 3文字未満の場合はチェックしない
    if (username.length < 3) {
      setState(() {
        _isUsernameAvailable = null;
        _isCheckingUsername = false;
      });
      return;
    }

    // 英数字とアンダースコアのみかチェック
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      setState(() {
        _isUsernameAvailable = null;
        _isCheckingUsername = false;
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
    });

    // 500ms後にAPIを呼び出す（デバウンス）
    _usernameCheckTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final response = await _apiService.get(
          '/users/check-username',
          queryParams: {'username': username},
          requiresAuth: false,
        );

        if (mounted) {
          setState(() {
            _isUsernameAvailable = response['available'] as bool;
            _isCheckingUsername = false;
          });
        }
      } catch (e) {
        print('[SignupScreen] Username check error: $e');
        if (mounted) {
          setState(() {
            _isUsernameAvailable = null;
            _isCheckingUsername = false;
          });
        }
      }
    });
  }

  /// Email重複チェック（デバウンス処理付き）
  void _checkEmailAvailability(String email) {
    // タイマーをキャンセル
    _emailCheckTimer?.cancel();

    // メールアドレス形式でない場合はチェックしない
    if (!email.contains('@')) {
      setState(() {
        _isEmailAvailable = null;
        _isCheckingEmail = false;
      });
      return;
    }

    setState(() {
      _isCheckingEmail = true;
    });

    // 500ms後にAPIを呼び出す（デバウンス）
    _emailCheckTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final response = await _apiService.get(
          '/users/check-email',
          queryParams: {'email': email},
          requiresAuth: false,
        );

        if (mounted) {
          setState(() {
            _isEmailAvailable = response['available'] as bool;
            _isCheckingEmail = false;
          });
        }
      } catch (e) {
        print('[SignupScreen] Email check error: $e');
        if (mounted) {
          setState(() {
            _isEmailAvailable = null;
            _isCheckingEmail = false;
          });
        }
      }
    });
  }

  void _goToStep2() {
    if (_formKeyStep1.currentState!.validate()) {
      setState(() {
        _currentStep = 1;
      });
    }
  }

  void _goBackToStep1() {
    setState(() {
      _currentStep = 0;
    });
  }

  Future<void> _handleSignup() async {
    if (!_formKeyStep2.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.signup(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _displayNameController.text.trim(),
      );

      if (!mounted) return;

      if (result.success) {
        // 登録成功
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        // エラー表示
        _showError(result.errorMessage ?? '登録に失敗しました');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),

                // Back button
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                      onPressed: () {
                        if (_currentStep == 0) {
                          Navigator.of(context).pop();
                        } else {
                          _goBackToStep1();
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Logo/Title
                Text(
                  'Sign Up',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge,
                ),

                const SizedBox(height: 12),

                // Step Indicator
                Text(
                  'Step ${_currentStep + 1}/2',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 40),

                // Form Container
                if (_currentStep == 0) _buildStep1() else _buildStep2(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
      child: Form(
        key: _formKeyStep1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Display Name Field
            _buildLabel('表示名'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _displayNameController,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: '田中太郎',
                hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '表示名を入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Username Field
            _buildLabel('ユーザID'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _usernameController,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'tanaka_taro',
                hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
                helperText: 'フレンド検索時に使用されます\n英数字とアンダースコアのみ（3〜20文字）',
                helperStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
                helperMaxLines: 2,
                suffixIcon: _isCheckingUsername
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(AppColors.primary),
                          ),
                        ),
                      )
                    : _isUsernameAvailable == true
                        ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                        : _isUsernameAvailable == false
                            ? const Icon(Icons.error, color: Colors.red, size: 20)
                            : null,
              ),
              onChanged: (value) {
                setState(() {});
                _checkUsernameAvailability(value.trim());
              },
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'ユーザIDを入力してください';
                }
                if (value.trim().length < 3 || value.trim().length > 20) {
                  return 'ユーザIDは3〜20文字で入力してください';
                }
                if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
                  return '英数字とアンダースコアのみ使用できます';
                }
                return null;
              },
            ),
            if (_isUsernameAvailable == false) ...[
              const SizedBox(height: 4),
              Text(
                'このユーザIDは既に使用されています',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.red,
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Email Field
            _buildLabel('メールアドレス'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              style: Theme.of(context).textTheme.bodyLarge,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'your@email.com',
                hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
                suffixIcon: _isCheckingEmail
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(AppColors.primary),
                          ),
                        ),
                      )
                    : _isEmailAvailable == true
                        ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                        : _isEmailAvailable == false
                            ? const Icon(Icons.error, color: Colors.red, size: 20)
                            : null,
              ),
              onChanged: (value) {
                setState(() {});
                _checkEmailAvailability(value.trim());
              },
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'メールアドレスを入力してください';
                }
                if (!value.contains('@')) {
                  return '有効なメールアドレスを入力してください';
                }
                return null;
              },
            ),
            if (_isEmailAvailable == false) ...[
              const SizedBox(height: 4),
              Text(
                'このメールアドレスは既に使用されています',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.red,
                ),
              ),
            ],
            const SizedBox(height: 32),

            // Next Button
            SizedBox(
              height: 48,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: _isStep1Valid ? AppColors.buttonShadow : null,
                ),
                child: ElevatedButton(
                  onPressed: _isStep1Valid ? _goToStep2 : null,
                  child: const Text(
                    '次へ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.31,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Sign In Link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account?',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Sign In',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
      child: Form(
        key: _formKeyStep2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Password Field
            _buildLabel('パスワード'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: '••••••••',
                hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
                helperText: '8文字以上',
                helperStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textPlaceholder,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'パスワードを入力してください';
                }
                if (value.length < 8) {
                  return 'パスワードは8文字以上で入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Confirm Password Field
            _buildLabel('パスワード（確認）'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: '••••••••',
                hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textPlaceholder,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'パスワード（確認）を入力してください';
                }
                if (value != _passwordController.text) {
                  return 'パスワードが一致しません';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Sign Up Button
            SizedBox(
              height: 48,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: _isStep2Valid ? AppColors.buttonShadow : null,
                ),
                child: ElevatedButton(
                  onPressed: _isStep2Valid && !_isLoading ? _handleSignup : null,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(AppColors.textWhite),
                          ),
                        )
                      : const Text(
                          'Sign Up',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -0.31,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge,
    );
  }
}
