import 'package:flutter/material.dart';

/// Colors taken from the Lumora / Apple design system.
class AppColors {
  static const actionBlue = Color(0xFF0066CC);
  static const primaryFocus = Color(0xFF0071E3);
  static const canvas = Color(0xFFFFFFFF);
  static const parchment = Color(0xFFF5F5F7);
  static const pearl = Color(0xFFFAFAFC);
  static const tileDark = Color(0xFF272729);
  static const ink = Color(0xFF1D1D1F);
  static const inkMuted = Color(0xFF7A7A7A);
  static const hairline = Color(0xFFE0E0E0);
  static const dividerSoft = Color(0xFFF0F0F0);
}

/// Apple-flavoured theme. SF Pro isn't available on Android, so we approximate
/// its feel with the signature negative letter-spacing, 17px body, and the
/// deliberate absence of weight 500 (we use 400 / 600).
ThemeData buildAppleTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.actionBlue,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.actionBlue,
    surface: AppColors.canvas,
  );

  const textTheme = TextTheme(
    headlineMedium: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.374,
        height: 1.1,
        color: AppColors.ink),
    titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: AppColors.ink),
    titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.374,
        color: AppColors.ink),
    bodyLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.374,
        height: 1.35,
        color: AppColors.ink),
    bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.2,
        height: 1.35,
        color: AppColors.ink),
    labelLarge: TextStyle(
        fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: -0.2),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.parchment,
    textTheme: textTheme,
    dividerTheme: const DividerThemeData(
        color: AppColors.dividerSoft, thickness: 1, space: 1),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.parchment,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: AppColors.ink),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.actionBlue
            : const Color(0xFFD1D1D6),
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.actionBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(980)),
        textStyle: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: -0.2),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      ),
    ),
  );
}
