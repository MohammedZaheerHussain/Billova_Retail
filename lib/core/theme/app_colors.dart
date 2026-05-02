import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Primary Palette ───
  static const Color primary = Color(0xFF2563EB); // Royal Blue
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryDark = Color(0xFF1D4ED8);

  // ─── Accent ───
  static const Color accent = Color(0xFF06B6D4); // Cyan
  static const Color accentGlow = Color(0x3306B6D4);

  // ─── Surface (Dark Theme — Deep Navy) ───
  static const Color scaffoldDark = Color(0xFF060D1B);
  static const Color surfaceDark = Color(0xFF0B1426);
  static const Color cardDark = Color(0xFF0F1D32);
  static const Color cardBorderDark = Color(0xFF1A2D4A);

  // ─── Surface (Light Theme — Clean SaaS) ───
  static const Color scaffoldLight = Color(0xFFF1F5F9);
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardBorderLight = Color(0xFFE2E8F0);

  // ─── Text ───
  static const Color textPrimaryDark = Color(0xFFEDF2F7);
  static const Color textSecondaryDark = Color(0xFF8899AC);
  static const Color textTertiaryDark = Color(0xFF4A6178);
  
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textTertiaryLight = Color(0xFF94A3B8);

  // ─── Semantic ───
  static const Color success = Color(0xFF10B981);
  static const Color successBg = Color(0x1A10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBg = Color(0x1AF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color errorBg = Color(0x1AEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoBg = Color(0x1A3B82F6);

  // ─── Sidebar ───
  static const Color sidebarDark = Color(0xFF081020);
  static const Color sidebarLight = Color(0xFF0F1D32);
  static const Color sidebarActiveItem = Color(0xFF2563EB);

  // ─── Gradients ───
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGlowGradient = LinearGradient(
    colors: [Color(0x202563EB), Color(0x2006B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF06D6A0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Theme-Aware Helpers ───
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? textPrimaryDark : textPrimaryLight;

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? textSecondaryDark : textSecondaryLight;

  static Color textTertiary(BuildContext context) =>
      isDark(context) ? textTertiaryDark : textTertiaryLight;

  static Color card(BuildContext context) =>
      isDark(context) ? cardDark : cardLight;

  static Color cardBorder(BuildContext context) =>
      isDark(context) ? cardBorderDark : cardBorderLight;

  static Color surface(BuildContext context) =>
      isDark(context) ? surfaceDark : surfaceLight;

  static Color scaffold(BuildContext context) =>
      isDark(context) ? scaffoldDark : scaffoldLight;
}
