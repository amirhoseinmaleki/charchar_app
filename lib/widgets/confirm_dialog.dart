import 'package:animated_button/animated_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sound_provider.dart';
import '../theme/app_images.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import './p_text.dart';

/// A yes/no confirmation, styled like [InsufficientCoinsDialog]: warning
/// artwork, scale-in animation, big [_DialogButton]s. [show] resolves to
/// `true` when the confirm button is tapped, `false`/`null` otherwise.
class ConfirmDialog extends ConsumerWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = 'انصراف',
    this.destructive = true,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;

  /// Colours the confirm button red (a delete/leave action).
  final bool destructive;

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'انصراف',
    bool destructive = true,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, a, b) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
      ),
      transitionBuilder: (context, animation, secondary, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: Tween<double>(begin: 0.85, end: 1).animate(curved), child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameTheme = context.gameTheme;
    final confirmColor = destructive ? gameTheme.invalidColor : gameTheme.baseGradient.colors.first;

    return Dialog(
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(AppImages.warning, width: 64, height: 64),
            const SizedBox(height: AppSpacing.lg),
            PText(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            PText(message, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xl),
            _DialogButton(
              label: confirmLabel,
              gradient: LinearGradient(colors: [confirmColor, confirmColor]),
              onTap: () {
                ref.read(soundServiceProvider).playButtonClick();
                Navigator.of(context).pop(true);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            _DialogButton(
              label: cancelLabel,
              gradient: gameTheme.baseGradient,
              onTap: () {
                ref.read(soundServiceProvider).playButtonClick();
                Navigator.of(context).pop(false);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({required this.label, required this.gradient, required this.onTap});

  final String label;
  final Gradient gradient;
  final VoidCallback onTap;

  static const _height = 48.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth && constraints.maxWidth.isFinite ? constraints.maxWidth : 200.0;
        return AnimatedButton(
          width: width,
          height: _height,
          borderRadius: AppRadius.sm,
          color: gradient.colors.first,
          onPressed: onTap,
          child: Container(
            width: width,
            height: _height,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            alignment: Alignment.center,
            child: PText(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        );
      },
    );
  }
}
