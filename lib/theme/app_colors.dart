import 'package:flutter/material.dart';

/// Raw color tokens. Referenced by [AppTheme] and [GameColors] — never used
/// directly in widgets so a future palette change only touches this file.
class AppColors {
  AppColors._();

  // Brand gradient (hero elements)
  static const violet = Color(0xFF7C3AED);
  static const magenta = Color(0xFFEC4899);

  // Base button gradient (default CTA color across the app)
  static const green = Color(0xFF16A34A);
  static const greenDark = Color(0xFF15803D);

  // Game feedback colors
  static const gold = Color(0xFFF5C542); // unique / best answer
  static const silver = Color(0xFFB0B7C3); // shared answer
  static const invalidRose = Color(0xFFF43F5E); // invalid
  static const emerald = Color(0xFF10B981); // correct vote / success

  // Dark theme surfaces
  static const darkBackground = Color(0xFF14121F);
  static const darkSurface = Color(0xFF1D1A2B);
  static const darkSurfaceElevated = Color(0xFF262238);
  static const darkBorder = Color(0xFF352F4A);

  // Light theme surfaces
  static const lightBackground = Color(0xFFFAF9FC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceElevated = Color(0xFFF3F1F8);
  static const lightBorder = Color(0xFFE3DFEE);

  // Text
  static const darkTextPrimary = Color(0xFFF5F3FA);
  static const darkTextSecondary = Color(0xFFAFA9C4);
  static const lightTextPrimary = Color(0xFF1D1A2B);
  static const lightTextSecondary = Color(0xFF635C7A);
}
