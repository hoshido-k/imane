import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/password_reset_screen.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase初期化（既に初期化されている場合はスキップ）
  try {
    print('[Main] Initializing Firebase...');
    print('[Main] Project ID: ${DefaultFirebaseOptions.currentPlatform.projectId}');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('[Main] Firebase initialized successfully');
  } catch (e) {
    // 既に初期化されている場合はエラーを無視
    if (e.toString().contains('duplicate-app')) {
      print('[Main] Firebase already initialized, skipping...');
    } else {
      print('[Main] Firebase initialization failed: $e');
      rethrow;
    }
  }

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ImaneApp());
}

class ImaneApp extends StatelessWidget {
  const ImaneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'imane',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/password-reset': (context) => const PasswordResetScreen(),
        '/map': (context) => const MainScreen(),
      },
    );
  }
}
