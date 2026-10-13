import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Game-specific design tokens not covered by Material's [ColorScheme]:
/// the brand gradient, per-round-result feedback colors, and card shadows.
/// Access via `Theme.of(context).extension<GameTheme>()!`.
class GameTheme extends ThemeExtension<GameTheme> {
  const GameTheme({
    required this.heroGradient,
    required this.baseGradient,
    required this.goldColor,
    required this.silverColor,
    required this.invalidColor,
    required this.successColor,
    required this.cardShadow,
  });

  final Gradient heroGradient;

  /// Default gradient for the app's primary CTA buttons ([GradientButton]).
  /// Green — the "base button color" for a game where the main action is
  /// almost always a "go/start/submit" affordance.
  final Gradient baseGradient;
  final Color goldColor;
  final Color silverColor;
  final Color invalidColor;
  final Color successColor;
  final List<BoxShadow> cardShadow;

  static const _heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.violet, AppColors.magenta],
  );

  static const _baseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.green, AppColors.greenDark],
  );

  static const dark = GameTheme(
    heroGradient: _heroGradient,
    baseGradient: _baseGradient,
    goldColor: AppColors.gold,
    silverColor: AppColors.silver,
    invalidColor: AppColors.invalidRose,
    successColor: AppColors.emerald,
    cardShadow: [
      BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 8)),
    ],
  );

  static const light = GameTheme(
    heroGradient: _heroGradient,
    baseGradient: _baseGradient,
    goldColor: AppColors.gold,
    silverColor: AppColors.silver,
    invalidColor: AppColors.invalidRose,
    successColor: AppColors.emerald,
    cardShadow: [
      BoxShadow(color: Color(0x1A1D1A2B), blurRadius: 20, offset: Offset(0, 6)),
    ],
  );

  @override
  GameTheme copyWith({
    Gradient? heroGradient,
    Gradient? baseGradient,
    Color? goldColor,
    Color? silverColor,
    Color? invalidColor,
    Color? successColor,
    List<BoxShadow>? cardShadow,
  }) {
    return GameTheme(
      heroGradient: heroGradient ?? this.heroGradient,
      baseGradient: baseGradient ?? this.baseGradient,
      goldColor: goldColor ?? this.goldColor,
      silverColor: silverColor ?? this.silverColor,
      invalidColor: invalidColor ?? this.invalidColor,
      successColor: successColor ?? this.successColor,
      cardShadow: cardShadow ?? this.cardShadow,
    );
  }

  @override
  GameTheme lerp(ThemeExtension<GameTheme>? other, double t) {
    if (other is! GameTheme) return this;
    return t < 0.5 ? this : other;
  }
}
