import 'package:animated_button/animated_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sound_provider.dart';
import '../theme/app_images.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import './p_text.dart';

/// The app's single error surface: every "insufficient_coins", "room not
/// found", wrong/expired OTP, invalid nickname, server-unreachable, etc.
/// message shows here instead of as inline red text under an input box —
/// a dialog is impossible to miss and always dismissible the same way.
class ErrorDialog extends ConsumerWidget {
  const ErrorDialog({super.key, required this.message, this.title});

  final String message;
  final String? title;

  static Future<void> show(BuildContext context, String message, {String? title}) {
    return showDialog<void>(
      context: context,
      builder: (context) => ErrorDialog(message: message, title: title),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            PText(
              title ?? 'خطا',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            PText(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            _DialogButton(
              label: 'متوجه شدم',
              onTap: () {
                ref.read(soundServiceProvider).playButtonClick();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  static const _height = 48.0;

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth && constraints.maxWidth.isFinite ? constraints.maxWidth : 200.0;
        return AnimatedButton(
          width: width,
          height: _height,
          borderRadius: AppRadius.sm,
          color: gameTheme.baseGradient.colors.first,
          onPressed: onTap,
          child: Container(
            width: width,
            height: _height,
            decoration: BoxDecoration(
              gradient: gameTheme.baseGradient,
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
