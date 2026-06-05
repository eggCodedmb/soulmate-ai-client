import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// SoulMate AI 文字样式常量
class AppTextStyles {
  /// 获取主题文字样式
  static TextTheme getTextTheme(Brightness brightness) {
    final baseTheme = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;

    return GoogleFonts.notoSansScTextTheme(baseTheme).copyWith(
      displayLarge: GoogleFonts.notoSansSc(
        fontSize: 57,
        fontWeight: FontWeight.w400,
      ),
      headlineLarge: GoogleFonts.notoSansSc(
        fontSize: 32,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: GoogleFonts.notoSansSc(
        fontSize: 28,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: GoogleFonts.notoSansSc(
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.notoSansSc(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.notoSansSc(
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: GoogleFonts.notoSansSc(
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: GoogleFonts.notoSansSc(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      labelMedium: GoogleFonts.notoSansSc(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: GoogleFonts.notoSansSc(
        fontSize: 11,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
