import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Primary Palette ───
  static const Color primary = Color(0xFF4F46E5); // Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF3730A3);

  // ─── Accent ───
  static const Color accent = Color(0xFF06B6D4); // Cyan
  static const Color accentGlow = Color(0x3306B6D4);

  // ─── Surface (Dark Theme) ───
  static const Color scaffoldDark = Color(0xFF0A0A1A);
  static const Color surfaceDark = Color(0xFF12122A);
  static const Color cardDark = Color(0xFF1A1A3E);
  static const Color cardBorderDark = Color(0xFF2A2A5E);

  // ─── Surface (Light Theme — SaaS/Stripe style) ───
  static const Color scaffoldLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFF1F5F9);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardBorderLight = Color(0xFFE2E8F0);

  // ─── Text ───
  static const Color textPrimaryDark = Color(0xFFF0F0FF);
  static const Color textSecondaryDark = Color(0xFF8888AA);
  static const Color textTertiaryDark = Color(0xFF555577);
  
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textTertiaryLight = Color(0xFF94A3B8);

  // ─── Semantic ───
  static const Color success = Color(0xFF00E676);
  static const Color successBg = Color(0x1A00E676);
  static const Color warning = Color(0xFFFFD600);
  static const Color warningBg = Color(0x1AFFD600);
  static const Color error = Color(0xFFFF5252);
  static const Color errorBg = Color(0x1AFF5252);
  static const Color info = Color(0xFF448AFF);
  static const Color infoBg = Color(0x1A448AFF);

  // ─── Sidebar ───
  static const Color sidebarDark = Color(0xFF0E0E24);
  static const Color sidebarLight = Color(0xFFFFFFFF);
  static const Color sidebarActiveItem = Color(0xFF4F46E5);

  // ─── Gradients ───
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGlowGradient = LinearGradient(
    colors: [Color(0x204F46E5), Color(0x2006B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00E676), Color(0xFF00BFA5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFFFD600), Color(0xFFFF9100)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
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
