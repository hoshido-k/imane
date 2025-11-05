import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isSignupMode = false; // false=ログイン, true=新規登録

  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (result.success) {
        // ログイン成功
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        // エラー表示
        _showError(result.errorMessage ?? 'ログインに失敗しました');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.signup(
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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top spacing (reduced from 210 to 140)
                  const SizedBox(height: 140),

                  // Logo/Title
                  Text(
                    'imane',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayLarge,
                  ),

                  const SizedBox(height: 40),

                  // Form Container
                  Container(
                    padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Display Name Field (新規登録時のみ)
                        if (_isSignupMode) ...[
                          _buildLabel('表示名'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _displayNameController,
                            style: Theme.of(context).textTheme.bodyLarge,
                            decoration: InputDecoration(
                              hintText: 'あなたの名前',
                              hintStyle: Theme.of(context)
                                  .inputDecorationTheme
                                  .hintStyle,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '表示名を入力してください';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Email Field
                        _buildLabel('メールアドレス'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          style: Theme.of(context).textTheme.bodyLarge,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'your@email.com',
                            hintStyle:
                                Theme.of(context).inputDecorationTheme.hintStyle,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'メールアドレスを入力してください';
                            }
                            if (!value.contains('@')) {
                              return '有効なメールアドレスを入力してください';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Password Field
                        _buildLabel('パスワード'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: Theme.of(context).textTheme.bodyLarge,
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            hintStyle:
                                Theme.of(context).inputDecorationTheme.hintStyle,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
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
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'パスワードを入力してください';
                            }
                            if (_isSignupMode && value.length < 8) {
                              return 'パスワードは8文字以上で入力してください';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Sign In Button
                        SizedBox(
                          height: 48,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: AppColors.buttonShadow,
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : (_isSignupMode ? _handleSignup : _handleLogin),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                            AppColors.textWhite),
                                      ),
                                    )
                                  : Text(
                                      _isSignupMode ? 'Sign Up' : 'Sign in',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: -0.31,
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Sign Up Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isSignupMode
                                  ? 'Already have an account?'
                                  : "Don't have an account?",
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isSignupMode = !_isSignupMode;
                                });
                              },
                              child: Text(
                                _isSignupMode ? 'Sign In' : 'Sign Up',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w400,
                                    ),
                              ),
                            ),
                          ],
                        ),

                        // Forgot Password Link (ログインモード時のみ)
                        if (!_isSignupMode) ...[
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pushNamed('/password-reset');
                            },
                            child: Text(
                              'Forgot password?',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w400,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
