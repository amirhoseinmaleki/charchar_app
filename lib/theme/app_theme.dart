import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'game_theme_extension.dart';

class AppTheme {
  AppTheme._();

  // Lalezar is a single-weight (Regular) rounded display face — it reads as
  // bold on its own, so the FontWeight.w600/w700 in the text theme below
  // just have no extra effect rather than triggering fake-bold.
  static const _fontFamily = 'Lalezar';

  static TextTheme _textTheme(Color primary, Color secondary) {
    final base = Typography.material2021().black;
    return base
        .copyWith(
          displayLarge: base.displayLarge?.copyWith(fontWeight: FontWeight.w700, color: primary),
          displayMedium: base.displayMedium?.copyWith(fontWeight: FontWeight.w700, color: primary),
          headlineLarge: base.headlineLarge?.copyWith(fontWeight: FontWeight.w700, color: primary),
          headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w700, color: primary),
          titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: primary),
          titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w500, color: primary),
          bodyLarge: base.bodyLarge?.copyWith(color: primary),
          bodyMedium: base.bodyMedium?.copyWith(color: secondary),
          labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600, color: primary),
        )
        .apply(fontFamily: _fontFamily, fontSizeFactor: 1.0);
  }

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.violet,
      secondary: AppColors.magenta,
      surface: AppColors.darkSurface,
      error: AppColors.invalidRose,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.darkTextPrimary,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      textTheme: _textTheme(AppColors.darkTextPrimary, AppColors.darkTextSecondary),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.violet, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.minTouchTarget + 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        ),
      ),
      extensions: const [GameTheme.dark],
    );
  }

  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppColors.violet,
      secondary: AppColors.magenta,
      surface: AppColors.lightSurface,
      error: AppColors.invalidRose,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.lightTextPrimary,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      textTheme: _textTheme(AppColors.lightTextPrimary, AppColors.lightTextSecondary),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.lightTextPrimary,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.violet, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.minTouchTarget + 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        ),
      ),
      extensions: const [GameTheme.light],
    );
  }
}

extension GameThemeContext on BuildContext {
  GameTheme get gameTheme => Theme.of(this).extension<GameTheme>()!;
}
