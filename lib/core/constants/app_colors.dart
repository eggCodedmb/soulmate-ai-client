import 'package:flutter/material.dart';

/// SoulMate AI 颜色常量
class AppColors {
  // Brand Colors
  static const Color brandPink = Color(0xFFFF6B8A);
  static const Color brandPinkDark = Color(0xFFFF8FA8);
  static const Color brandLavender = Color(0xFFA78BFA);
  static const Color brandLavenderDark = Color(0xFFC4B5FD);
  static const Color brandWarmPeach = Color(0xFFFFB88C);
  static const Color brandWarmPeachDark = Color(0xFFFFCBA4);

  // Light Theme Colors
  static const Color lightSurface = Color(0xFFFAFAFA);
  static const Color lightSurfaceContainerHighest = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerLow = Color(0xFFF2F2F7);
  static const Color lightOnSurface = Color(0xFF1A1A2E);
  static const Color lightOnSurfaceVariant = Color(0xFF6B7280);
  static const Color lightOutline = Color(0xFFE5E7EB);

  // Dark Theme Colors
  static const Color darkSurface = Color(0xFF000000);
  static const Color darkSurfaceContainerHighest = Color(0xFF1C1C1E);
  static const Color darkSurfaceContainerLow = Color(0xFF2C2C2E);
  static const Color darkOnSurface = Color(0xFFFFFFFF);
  static const Color darkOnSurfaceVariant = Color(0xFF9CA3AF);
  static const Color darkOutline = Color(0xFF374151);

  // AI Partner Personality Theme Colors
  static const Map<String, PersonalityColors> personalityColors = {
    'gentle': PersonalityColors(
      light: Color(0xFFFFE4EC),
      dark: Color(0xFF3D2A30),
      name: 'Soft Rose',
    ),
    'lively': PersonalityColors(
      light: Color(0xFFFFF3E0),
      dark: Color(0xFF3D3225),
      name: 'Warm Peach',
    ),
    'calm': PersonalityColors(
      light: Color(0xFFE3F2FD),
      dark: Color(0xFF1E2A3A),
      name: 'Calm Blue',
    ),
    'humorous': PersonalityColors(
      light: Color(0xFFFFFDE7),
      dark: Color(0xFF3D3A25),
      name: 'Sunny Yellow',
    ),
    'intellectual': PersonalityColors(
      light: Color(0xFFF3E5F5),
      dark: Color(0xFF2E1F35),
      name: 'Muted Purple',
    ),
    'cool': PersonalityColors(
      light: Color(0xFFECEFF1),
      dark: Color(0xFF25282C),
      name: 'Cool Gray',
    ),
  };

  // Semantic Colors
  static const Color success = Colors.green;
  static const Color warning = Colors.amber;
  static const Color error = Colors.red;
  static const Color info = Colors.blue;

  // Gradient Presets
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [brandPink, brandWarmPeach],
  );

  static const LinearGradient brandGradientDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A0A10), Color(0xFF2D1520)],
  );
}

/// AI伴侣性格主题颜色
class PersonalityColors {
  final Color light;
  final Color dark;
  final String name;

  const PersonalityColors({
    required this.light,
    required this.dark,
    required this.name,
  });
}
