import 'package:animated_button/animated_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sound_provider.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import './p_text.dart';

/// The app's single primary action button — filled with the hero gradient
/// so every "ثبت", "شروع بازی", "بازی دوباره" style CTA carries the same
/// game-like visual weight, plus the shared 3D-press [AnimatedButton] feel
/// and a click sound, instead of falling back to Material's flat default
/// ElevatedButton. Use this (or [GradientOutlinedButton] for a secondary
/// action) instead of bare ElevatedButton/OutlinedButton anywhere a player
/// taps to move the game forward.
class GradientButton extends ConsumerWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.isLoading = false,
    this.gradient,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool isLoading;

  /// Defaults to the theme's base gradient (green) when omitted.
  final Gradient? gradient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDisabled = onTap == null || isLoading;
    final effectiveGradient = gradient ?? context.gameTheme.baseGradient;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth && constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 200.0;

        return AnimatedButton(
          width: width,
          height: AppSpacing.minTouchTarget + 4,
          borderRadius: AppRadius.sm,
          color: effectiveGradient.colors.first,
          enabled: !isDisabled,
          onPressed: () {
            ref.read(soundServiceProvider).playButtonClick();
            onTap?.call();
          },
          child: Container(
            width: width,
            height: AppSpacing.minTouchTarget + 4,
            decoration: BoxDecoration(
              gradient: effectiveGradient,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        PText(
                          label,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// Secondary action — outlined with the hero gradient's leading color
/// instead of filled, for a "less important than the primary CTA" action
/// that should still read as belonging to the same button family (e.g.
/// "اشتراک‌گذاری نتیجه" next to a filled "بازی دوباره").
class GradientOutlinedButton extends ConsumerWidget {
  const GradientOutlinedButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = context.gameTheme.baseGradient.colors.first;
    final isDisabled = onTap == null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth && constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 200.0;

        return AnimatedButton(
          width: width,
          height: AppSpacing.minTouchTarget + 4,
          borderRadius: AppRadius.sm,
          color: Colors.transparent,
          disabledColor: Colors.transparent,
          enabled: !isDisabled,
          onPressed: () {
            ref.read(soundServiceProvider).playButtonClick();
            onTap?.call();
          },
          child: Container(
            width: width,
            height: AppSpacing.minTouchTarget + 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: color.withValues(alpha: isDisabled ? 0.4 : 1), width: 1.5),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  PText(
                    label,
                    style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
