import 'package:flutter/material.dart';

class FiloColors {
  FiloColors._();
  static const background = Color(0xFFF9FAF5);
  static const primary = Color(0xFF236B57);
  static const edge = Color(0xFF1A5444);
  static const ink = Color(0xFF14423A);
  static const secondary = Color(0xFF4F625A);
  static const mint = Color(0xFFDCE9DA);
  static const selected = Color(0xFFCFE8DC);
  static const border = Color(0xFFD9E2DA);
  static const tint = Color(0xFFF0F5F0);
  static const lime = Color(0xFFE0F0A6);
  static const limeDeep = Color(0xFFBCD27A);
  static const surface = Colors.white;
  static const disabledButtonFill = Color(0xFFE2E8E2);
  static const disabledButtonInk = Color(0xFF4F625A);
  static const disabledButtonBorder = Color(0xFFCCD7CE);
  static const onBanner = Colors.white;
  static const bannerOverlay = Color(0xB314231E);
  static const warningInk = Color(0xFF8A5200);
  static const error = Color(0xFFBA1A1A);
  static const warning = Color(0xFFFFF1D6);
}

class AppTheme {
  AppTheme._();

  static final dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Nunito',
    scaffoldBackgroundColor: const Color(0xFF0F1A17),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF5CBF9B),
      onPrimary: Color(0xFF06201A),
      surface: Color(0xFF16231F),
      onSurface: Color(0xFFE8F1EB),
      onSurfaceVariant: Color(0xFFA9BDB3),
      surfaceContainerHighest: Color(0xFF1B2B26),
      primaryContainer: Color(0xFF28483D),
      onPrimaryContainer: Color(0xFFE8F1EB),
      outline: Color(0xFF2B3F38),
      error: Color(0xFFF0A096),
      errorContainer: Color(0xFF3D1E1A),
      onErrorContainer: Color(0xFFF0A096),
    ),
    textTheme: light.textTheme.apply(
      bodyColor: const Color(0xFFE8F1EB),
      displayColor: const Color(0xFFE8F1EB),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0F1A17),
      foregroundColor: Color(0xFFE8F1EB),
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Color(0xFF16231F),
      indicatorColor: Color(0xFF28483D),
      elevation: 0,
    ),
    inputDecorationTheme: light.inputDecorationTheme.copyWith(
      fillColor: const Color(0xFF16231F),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: Color(0xFF2B3F38), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: Color(0xFF5CBF9B), width: 2),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF2B3F38)),
    snackBarTheme: light.snackBarTheme.copyWith(
      backgroundColor: const Color(0xFF28483D),
      contentTextStyle: const TextStyle(
        fontFamily: 'Nunito',
        color: Color(0xFFE8F1EB),
      ),
    ),
  );

  static final light = ThemeData(
    useMaterial3: true,
    fontFamily: 'Nunito',
    scaffoldBackgroundColor: FiloColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: FiloColors.primary,
      primary: FiloColors.primary,
      onPrimary: Colors.white,
      surface: FiloColors.background,
      onSurface: FiloColors.ink,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 36,
        height: 1.2,
        fontWeight: FontWeight.w900,
      ),
      headlineMedium: TextStyle(
        fontSize: 32,
        height: 1.25,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45),
      labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    ).apply(bodyColor: FiloColors.ink, displayColor: FiloColors.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: FiloColors.background,
      foregroundColor: FiloColors.ink,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: FiloColors.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: FiloColors.primary, width: 2),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: FiloColors.selected,
      elevation: 0,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: FiloColors.selected,
      side: const BorderSide(color: FiloColors.border),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: FiloColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: const DividerThemeData(color: FiloColors.border),
  );
}
