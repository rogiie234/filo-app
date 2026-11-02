import 'package:flutter/material.dart';

import 'filo_theme_tokens.dart';
export 'filo_theme_tokens.dart';

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
  static final light = _build(false);
  static final dark = _build(true);

  static ThemeData _build(bool dark) {
    final tokens = dark ? FiloThemeTokens.dark : FiloThemeTokens.light;
    final background = dark ? const Color(0xFF0F1A17) : FiloColors.background;
    final colors = ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: dark ? const Color(0xFF5CBF9B) : FiloColors.primary,
      onPrimary: dark ? const Color(0xFF06201A) : Colors.white,
      primaryContainer: dark ? const Color(0xFF28483D) : FiloColors.selected,
      onPrimaryContainer: dark ? const Color(0xFFE8F1EB) : FiloColors.ink,
      secondary: dark ? const Color(0xFFA9BDB3) : FiloColors.secondary,
      onSecondary: dark ? const Color(0xFF0F1A17) : Colors.white,
      secondaryContainer: tokens.mint,
      onSecondaryContainer: dark ? const Color(0xFFE8F1EB) : FiloColors.ink,
      tertiary: tokens.info,
      onTertiary: dark ? const Color(0xFF162B3D) : Colors.white,
      tertiaryContainer: tokens.infoTint,
      onTertiaryContainer: tokens.info,
      surface: dark ? const Color(0xFF16231F) : Colors.white,
      onSurface: dark ? const Color(0xFFE8F1EB) : FiloColors.ink,
      onSurfaceVariant: dark ? const Color(0xFFA9BDB3) : FiloColors.secondary,
      surfaceContainerLowest: background,
      surfaceContainerLow: dark ? const Color(0xFF16231F) : Colors.white,
      surfaceContainer: dark ? const Color(0xFF1B2B26) : FiloColors.tint,
      surfaceContainerHigh: dark ? const Color(0xFF1B2B26) : FiloColors.tint,
      surfaceContainerHighest: dark ? const Color(0xFF1B2B26) : FiloColors.tint,
      outline: dark ? const Color(0xFF2B3F38) : FiloColors.border,
      outlineVariant: dark ? const Color(0xFF2B3F38) : FiloColors.border,
      error: dark ? const Color(0xFFF0A096) : const Color(0xFFB3382C),
      onError: dark ? const Color(0xFF3D1E1A) : Colors.white,
      errorContainer: dark ? const Color(0xFF3D1E1A) : const Color(0xFFFBE4E0),
      onErrorContainer: dark
          ? const Color(0xFFF0A096)
          : const Color(0xFFB3382C),
      inverseSurface: FiloColors.ink,
      onInverseSurface: Colors.white,
      inversePrimary: const Color(0xFF5CBF9B),
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
    );
    final text =
        const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 36,
            height: 44 / 36,
            fontWeight: FontWeight.w900,
          ),
          headlineMedium: TextStyle(
            fontSize: 32,
            height: 40 / 32,
            fontWeight: FontWeight.w800,
          ),
          headlineSmall: TextStyle(
            fontSize: 22,
            height: 28 / 22,
            fontWeight: FontWeight.w700,
          ),
          titleLarge: TextStyle(
            fontSize: 22,
            height: 28 / 22,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: TextStyle(
            fontSize: 18,
            height: 24 / 18,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            height: 24 / 16,
            fontWeight: FontWeight.w400,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            height: 20 / 14,
            fontWeight: FontWeight.w400,
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w500,
          ),
          labelLarge: TextStyle(
            fontSize: 16,
            height: 20 / 16,
            fontWeight: FontWeight.w800,
          ),
          labelMedium: TextStyle(
            fontSize: 14,
            height: 20 / 14,
            fontWeight: FontWeight.w700,
          ),
          labelSmall: TextStyle(
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w500,
          ),
        ).apply(
          fontFamily: 'Nunito',
          bodyColor: colors.onSurface,
          displayColor: colors.onSurface,
        );
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide(color: color, width: width),
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Nunito',
      colorScheme: colors,
      scaffoldBackgroundColor: background,
      textTheme: text,
      extensions: [tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.primaryContainer,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        hintStyle: TextStyle(color: tokens.hint),
        labelStyle: TextStyle(color: colors.onSurfaceVariant),
        border: border(colors.outline, 1.5),
        enabledBorder: border(colors.outline, 1.5),
        disabledBorder: border(tokens.disabledBorder, 1.5),
        focusedBorder: border(colors.primary, 2),
        errorBorder: border(colors.error, 1.5),
        focusedErrorBorder: border(colors.error, 2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? tokens.disabledInk
              : states.contains(WidgetState.selected)
              ? colors.onPrimary
              : colors.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? tokens.disabledFill
              : states.contains(WidgetState.selected)
              ? colors.primary
              : tokens.mint,
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? tokens.disabledInk
              : states.contains(WidgetState.selected)
              ? colors.primary
              : colors.onSurfaceVariant,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surface,
        selectedColor: colors.primaryContainer,
        disabledColor: tokens.disabledFill,
        side: BorderSide(color: colors.outline),
        shape: const StadiumBorder(),
        labelStyle: text.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: colors.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: colors.outline),
    );
  }
}

/// Preserve the platform scaler (including nonlinear scaling) below the cap.
class FiloTextScale extends StatelessWidget {
  const FiloTextScale({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: child);
}
