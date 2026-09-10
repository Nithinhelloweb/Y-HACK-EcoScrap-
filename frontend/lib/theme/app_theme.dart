import 'package:flutter/material.dart';

class AppTheme {
  // Anthropic + Microsoft Warm Dark Palette
  static const Color bgDark = Color(0xFF141311);
  static const Color surfaceDark = Color(0xFF1C1A18);
  static const Color cardDark = Color(0xFF23201D);
  static const Color cardElevatedDark = Color(0xFF2C2824);
  static const Color borderDark = Color(0xFF38342F);
  static const Color borderSubtle = Color(0xFF38342F); // Backwards compatibility
  static const Color textPrimaryDark = Color(0xFFF9F7F5);
  static const Color textSecondaryDark = Color(0xFFA8A29A);
  static const Color textMutedDark = Color(0xFF756F67);

  // Anthropic + Microsoft Warm Light Palette (Default Mode)
  static const Color bgLight = Color(0xFFFAF9F5);
  static const Color surfaceLight = Color(0xFFF3F1EC);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardElevatedLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE5E2DA);
  static const Color textPrimaryLight = Color(0xFF1F1D1A);
  static const Color textSecondaryLight = Color(0xFF59544D);
  static const Color textMutedLight = Color(0xFF8C867D);

  // Backwards compatibility static constants (defaulting to primary/dark values)
  static const Color textPrimary = Color(0xFFF9F7F5);
  static const Color textSecondary = Color(0xFFA8A29A);
  static const Color textMuted = Color(0xFF756F67);

  // Brand & Role Accents (Microsoft Fluent 2 + Anthropic Claude)
  static const Color primaryGreen = Color(0xFF10B981);
  static const Color primaryGreenDark = Color(0xFF059669);
  static const Color collectorColor = Color(0xFF059669);
  static const Color recyclerColor = Color(0xFF0284C7);
  static const Color adminColor = Color(0xFF7C3AED);
  static const Color copperAccent = Color(0xFFC2410C); // Anthropic Terracotta / Copper

  // Status & Utility Colors
  static const Color alertAmber = Color(0xFFD97706);
  static const Color alertRed = Color(0xFFDC2626);
  static const Color infoBlue = Color(0xFF2563EB);

  // Theme-aware helper functions
  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  static Color getBg(BuildContext context) => isDark(context) ? bgDark : bgLight;
  static Color getSurface(BuildContext context) => isDark(context) ? surfaceDark : surfaceLight;
  static Color getCardBg(BuildContext context) => isDark(context) ? cardDark : cardLight;
  static Color getBorder(BuildContext context) => isDark(context) ? borderDark : borderLight;
  static Color getTextPrimary(BuildContext context) => isDark(context) ? textPrimaryDark : textPrimaryLight;
  static Color getTextSecondary(BuildContext context) => isDark(context) ? textSecondaryDark : textSecondaryLight;
  static Color getTextMuted(BuildContext context) => isDark(context) ? textMutedDark : textMutedLight;

  static Color getRoleColor(BuildContext context, String role) {
    final dark = isDark(context);
    switch (role.toUpperCase()) {
      case 'COLLECTOR':
        return dark ? const Color(0xFF10B981) : const Color(0xFF059669);
      case 'RECYCLER':
        return dark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
      case 'ADMIN':
        return dark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
      default:
        return dark ? const Color(0xFF10B981) : const Color(0xFF059669);
    }
  }

  // Theme-Adaptive Card Box Decoration (Fluent 2 Acrylic + Anthropic Warm Shadow)
  static BoxDecoration cardBoxDecoration({
    Color? color,
    Color? borderColor,
    double borderRadius = 16,
    bool glow = false,
    Color? glowColor,
    BuildContext? context,
  }) {
    final dark = context != null ? isDark(context) : true;
    final defaultBg = dark ? cardDark : cardLight;
    final defaultBorder = dark ? borderDark : borderLight;
    final effectiveColor = (color == null || color == cardDark) ? defaultBg : color;
    final effectiveBorderColor = (borderColor == null || borderColor == borderSubtle || borderColor == borderDark)
        ? defaultBorder
        : borderColor;

    return BoxDecoration(
      color: effectiveColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: effectiveBorderColor,
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: dark ? Colors.black.withValues(alpha: 0.35) : const Color(0xFF2B251F).withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
        if (glow && glowColor != null)
          BoxShadow(
            color: glowColor.withValues(alpha: dark ? 0.2 : 0.12),
            blurRadius: 18,
            spreadRadius: 1,
          ),
      ],
    );
  }

  // Theme-Adaptive Pill Badge Decoration
  static BoxDecoration pillBadgeDecoration(
    Color color, {
    double radius = 20,
    BuildContext? context,
  }) {
    final dark = context != null ? isDark(context) : true;
    return BoxDecoration(
      color: color.withValues(alpha: dark ? 0.16 : 0.1),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: color.withValues(alpha: dark ? 0.45 : 0.32),
        width: 1,
      ),
    );
  }

  // 1. Light ThemeData (DEFAULT)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgLight,
      colorScheme: const ColorScheme.light(
        primary: primaryGreenDark,
        secondary: Color(0xFF0D9488),
        surface: cardLight,
        error: Color(0xFFDC2626),
        onPrimary: Colors.white,
        onSurface: textPrimaryLight,
      ),
      cardTheme: const CardThemeData(
        color: cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: borderLight, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimaryLight,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: textPrimaryLight),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: const TextStyle(color: textMutedLight, fontSize: 14),
        labelStyle: const TextStyle(color: textSecondaryLight, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryGreenDark, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: alertRed),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreenDark,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimaryLight,
          side: const BorderSide(color: borderLight),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardLight,
        elevation: 0,
        indicatorColor: primaryGreenDark.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: primaryGreenDark,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textSecondaryLight,
          );
        }),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: cardLight,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: borderLight),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderLight,
        thickness: 1,
        space: 24,
      ),
    );
  }

  // 2. Dark ThemeData
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryGreen,
        secondary: primaryGreenDark,
        surface: surfaceDark,
        error: alertRed,
        onPrimary: Colors.black,
        onSurface: textPrimaryDark,
      ),
      cardTheme: const CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          side: BorderSide(color: borderDark, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimaryDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: textPrimaryDark),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: const TextStyle(color: textMutedDark, fontSize: 14),
        labelStyle: const TextStyle(color: textSecondaryDark, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: alertRed),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimaryDark,
          side: const BorderSide(color: borderDark),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bgDark,
        elevation: 0,
        indicatorColor: primaryGreen.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: primaryGreen,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textMutedDark,
          );
        }),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: cardDark,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: borderDark),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderDark,
        thickness: 1,
        space: 24,
      ),
    );
  }
}
