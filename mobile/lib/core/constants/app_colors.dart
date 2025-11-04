import 'package:flutter/material.dart';

/// App color constants based on Figma design
class AppColors {
  AppColors._();

  // Background Gradient Colors (Dark theme)
  static const Color backgroundDark1 = Color(0xFF0A0E27);
  static const Color backgroundDark2 = Color(0xFF1A1F3A);
  static const Color backgroundDark3 = Color(0xFF2A3158);

  // Primary Colors
  static const Color primary = Color(0xFF5B6FED);
  static const Color primaryHover = Color(0xFF4A5EDC);

  // Text Colors
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGray = Color(0xFFD1D5DB);
  static const Color textGrayDark = Color(0xFF9CA3AF);

  // Border Colors
  static const Color borderGray = Color(0xFF374151);

  // Card Background
  static const Color cardBackground = Color(0xFF1A1F3A);
  static const Color cardBackgroundHover = Color(0xFF252B4A);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // Gradient
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      backgroundDark1,
      backgroundDark2,
      backgroundDark3,
    ],
  );
}
