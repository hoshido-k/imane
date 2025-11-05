import 'package:flutter/material.dart';

/// App color constants based on Figma design
/// New warm beige/brown theme for imane
class AppColors {
  AppColors._();

  // Background Colors (Light theme - warm beige)
  static const Color background = Color(0xFFE8E4DF); // Main background

  // Primary Brand Color (Terracotta/Coral)
  static const Color primary = Color(0xFFB85D4D); // Main brand color
  static const Color primaryHover = Color(0xFFA54D3D);

  // Text Colors
  static const Color textPrimary = Color(0xFF5A4A40); // Dark brown for labels
  static const Color textSecondary = Color(0xFF8B7969); // Medium brown for secondary text
  static const Color textPlaceholder = Color(0xFF717182); // Gray for placeholders
  static const Color textWhite = Color(0xFFFFFFFF);

  // Input/Card Colors
  static const Color inputBackground = Color(0xFFF5F5F5); // Neutral 100
  static const Color inputBorder = Color(0xFFD8D4CF);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // Shadow
  static const List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: Color(0x1A000000), // rgba(0,0,0,0.1)
      offset: Offset(0, 4),
      blurRadius: 6,
      spreadRadius: -1,
    ),
    BoxShadow(
      color: Color(0x1A000000), // rgba(0,0,0,0.1)
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: -2,
    ),
  ];
}
