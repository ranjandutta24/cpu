import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// APP COLOR PALETTE — single source of truth
// ─────────────────────────────────────────────

class AppColors {
  AppColors._(); // non-instantiable

  // ── Brand / Accent ──────────────────────────
  static const Color accentTeal       = Color(0xFF3DD9B3);
  static const Color accentTealDark   = Color(0xFF1F6C78);
  static const Color accentTealLight  = Color(0xFF67E8C7);

  // ── Dark theme surfaces ──────────────────────
  static const Color darkBg           = Color(0xFF0D1117);
  static const Color darkBgGradMid    = Color(0xFF0F2027);
  static const Color darkSurface      = Color(0xFF161B22);
  static const Color darkBorder       = Color(0xFF30363D);
  static const Color darkInputFill    = Color(0xFF0D1117);

  // ── Dark theme text ──────────────────────────
  static const Color darkTextPrimary  = Color(0xFFE6EDF3);
  static const Color darkTextSecond   = Color(0xFF8B949E);
  static const Color darkTextHint     = Color(0xFF484F58);

  // ── Light theme surfaces ─────────────────────
  static const Color lightBg          = Color(0xFFF0F4F8);
  static const Color lightSurface     = Color(0xFFFFFFFF);
  static const Color lightBorder      = Color(0xFFD0D7DE);
  static const Color lightInputFill   = Color(0xFFF6F8FA);

  // ── Light theme text ─────────────────────────
  static const Color lightTextPrimary = Color(0xFF1C2128);
  static const Color lightTextSecond  = Color(0xFF57606A);
  static const Color lightTextHint    = Color(0xFFB0BAC3);

  // ── Semantic ─────────────────────────────────
  static const Color cpuChart         = Color(0xFF58A6FF);
  static const Color ramChart         = Color(0xFF3DD9B3);
  static const Color diskChart        = Color(0xFFF78166);
  static const Color success          = Color(0xFF3DD9B3);
  static const Color warning          = Color(0xFFD29922);
  static const Color error            = Color(0xFFF78166);
}

// ─────────────────────────────────────────────
// DARK THEME
// ─────────────────────────────────────────────

ThemeData get darkTheme => ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentTeal,
        secondary: AppColors.accentTealDark,
        surface: AppColors.darkSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.darkTextPrimary,
        error: AppColors.error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.darkSurface,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.accentTeal,
        textColor: AppColors.darkTextPrimary,
      ),
      textTheme: const TextTheme(
        bodyLarge:  TextStyle(color: AppColors.darkTextPrimary),
        bodyMedium: TextStyle(color: AppColors.darkTextPrimary),
        bodySmall:  TextStyle(color: AppColors.darkTextSecond),
        labelLarge: TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkInputFill,
        hintStyle: const TextStyle(color: AppColors.darkTextHint),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accentTeal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: AppColors.accentTeal,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      dividerColor: AppColors.darkBorder,
    );

// ─────────────────────────────────────────────
// LIGHT THEME
// ─────────────────────────────────────────────

ThemeData get lightTheme => ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accentTealDark,
        secondary: AppColors.accentTeal,
        surface: AppColors.lightSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.lightTextPrimary,
        error: AppColors.error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.lightSurface,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.accentTealDark,
        textColor: AppColors.lightTextPrimary,
      ),
      textTheme: const TextTheme(
        bodyLarge:  TextStyle(color: AppColors.lightTextPrimary),
        bodyMedium: TextStyle(color: AppColors.lightTextPrimary),
        bodySmall:  TextStyle(color: AppColors.lightTextSecond),
        labelLarge: TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightInputFill,
        hintStyle: const TextStyle(color: AppColors.lightTextHint),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accentTealDark, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: AppColors.accentTealDark,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      dividerColor: AppColors.lightBorder,
    );
