import 'package:flutter/material.dart';

class FirstVueColors {
  FirstVueColors._();

  // Theme 1B — Neon Service Luxe (teal + coral on deep purple)
  static const background = Color(0xFF0E0B1A);
  static const surface = Color(0xFF161222);
  static const elevatedSurface = Color(0xFF1C1829);
  static const gold = Color(0xFFE5C16F);
  static const warmGold = Color(0xFFD8B56A);
  static const teal = Color(0xFF3DD9C9);
  static const coral = Color(0xFFFF7A59);
  static const blush = Color(0xFFD68E98);
  static const ivory = Color(0xFFF4EFE6);
  static const mutedIcon = Color(0xFF8A9099);
}

class FirstVueTheme {
  FirstVueTheme._();

  static ThemeData get elegantDark {
    const scheme = ColorScheme.dark(
      surface: FirstVueColors.background,
      primary: FirstVueColors.gold,
      secondary: FirstVueColors.teal,
      tertiary: FirstVueColors.coral,
      onPrimary: Color(0xFF17130B),
      onSecondary: Color(0xFF071315),
      onSurface: FirstVueColors.ivory,
      error: Color(0xFFE39A9A),
    );

    const serif = 'CormorantGaramond';
    const sans = 'SpaceGrotesk';

    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: sans,
      scaffoldBackgroundColor: FirstVueColors.background,
      colorScheme: scheme,
      iconTheme: const IconThemeData(color: FirstVueColors.ivory),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: serif, fontWeight: FontWeight.w600),
        displayMedium: TextStyle(
          fontFamily: serif,
          fontWeight: FontWeight.w600,
        ),
        displaySmall: TextStyle(fontFamily: serif, fontWeight: FontWeight.w600),
        headlineLarge: TextStyle(
          fontFamily: serif,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: TextStyle(
          fontFamily: serif,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: TextStyle(
          fontFamily: serif,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(fontFamily: serif, fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: FirstVueColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: FirstVueColors.ivory,
        titleTextStyle: TextStyle(
          fontFamily: serif,
          color: FirstVueColors.ivory,
          fontSize: 23,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
        ),
      ),
      cardTheme: CardThemeData(
        color: FirstVueColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: FirstVueColors.teal.withValues(alpha: .18)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FirstVueColors.elevatedSurface,
        labelStyle: const TextStyle(color: Colors.white60),
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIconColor: FirstVueColors.gold,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: FirstVueColors.teal.withValues(alpha: .35)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FirstVueColors.coral,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: .6,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FirstVueColors.teal,
          side: BorderSide(color: FirstVueColors.teal.withValues(alpha: .55)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: FirstVueColors.background,
        indicatorColor: FirstVueColors.coral.withValues(alpha: .14),
        iconTheme: const WidgetStatePropertyAll(
          IconThemeData(color: FirstVueColors.mutedIcon),
        ),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w600, letterSpacing: .3),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: FirstVueColors.elevatedSurface,
        contentTextStyle: TextStyle(color: FirstVueColors.ivory),
      ),
      dividerColor: const Color(0x22F4EFE6),
    );
  }
}
