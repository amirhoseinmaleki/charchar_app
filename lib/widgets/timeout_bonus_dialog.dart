import 'package:animated_button/animated_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ad_reward_provider.dart';
import '../providers/remote_config_provider.dart';
import '../providers/round_provider.dart';
import '../providers/sound_provider.dart';
import '../services/ad_service.dart';
import '../theme/app_images.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import './p_text.dart';

/// Dialog shown when a player's round timer expires, offering +20s and 1 word hint
/// in exchange for watching a rewarded ad.
class TimeoutBonusDialog extends ConsumerStatefulWidget {
  const TimeoutBonusDialog({super.key, required this.roomCode});

  final String roomCode;

  static Future<Map<String, dynamic>?> show(BuildContext context, {required String roomCode}) {
    return showGeneralDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'timeout_bonus',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, a, b) => TimeoutBonusDialog(roomCode: roomCode),
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
  ConsumerState<TimeoutBonusDialog> createState() => _TimeoutBonusDialogState();
}

class _TimeoutBonusDialogState extends ConsumerState<TimeoutBonusDialog> {
  bool _busy = false;
  String? _errorMessage;

  Future<void> _watchAd() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    ref.read(soundServiceProvider).playButtonClick();

    final remoteConfig = ref.read(remoteConfigValueProvider);
    final result = await ref.read(adServiceProvider).watchRewardedAd(remoteConfig);
    if (kDebugMode) debugPrint('[TimeoutBonus] watchRewardedAd -> $result');
    if (!mounted) return;

    if (result != AdWatchResult.rewarded) {
      setState(() {
        _busy = false;
        _errorMessage = result == AdWatchResult.closedWithoutReward
            ? 'برای دریافت وقت اضافه باید ویدیو را تا انتها تماشا کنید.'
            : 'در حال حاضر تبلیغی موجود نیست.';
      });
      return;
    }

    try {
      final grantResult = await ref
          .read(roundControllerProvider.notifier)
          .claimTimeoutBonus(widget.roomCode);

      if (!mounted) return;
      if (grantResult != null && grantResult['success'] == true) {
        Navigator.of(context).pop(grantResult);
      } else {
        setState(() {
          _busy = false;
          _errorMessage = grantResult?['message'] as String? ?? 'خطا در اعمال پاداش زمان اضافه.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = 'ارتباط برقرار نشد.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;

    return Dialog(
      backgroundColor: const Color(0xFF231A38),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: Color(0xFF5E4592), width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(AppImages.stopWatch, width: 44, height: 44)
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .shake(duration: 800.ms, hz: 3),
                const SizedBox(width: AppSpacing.sm),
                Image.asset(AppImages.lightBulb, width: 44, height: 44)
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 600.ms),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            PText(
              'زمان شما تمام شد!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: const Color(0xFF2F244C),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: const Color(0xFF4C3A7A)),
              ),
              child: Column(
                children: [
                  PText(
                    '⚡ ۲۰ ثانیه زمان بیشتر',
                    style: const TextStyle(color: Color(0xFFF5C542), fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  PText(
                    '💡 همراه با پاسخ یکی از کلمات!',
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              PText(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: gameTheme.invalidColor),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            _ActionButton(
              label: _busy ? 'در حال بارگذاری…' : 'تماشای ویدیو و ادامه بازی',
              gradient: gameTheme.heroGradient,
              enabled: !_busy,
              busy: _busy,
              onTap: _watchAd,
            ),
            const SizedBox(height: AppSpacing.sm),
            _ActionButton(
              label: 'ثبت و پایان راند',
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.08),
                ],
              ),
              enabled: !_busy,
              onTap: () {
                ref.read(soundServiceProvider).playButtonClick();
                Navigator.of(context).pop(null);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.gradient,
    required this.onTap,
    this.enabled = true,
    this.busy = false,
  });

  final String label;
  final Gradient gradient;
  final VoidCallback onTap;
  final bool enabled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth && constraints.maxWidth.isFinite ? constraints.maxWidth : 220.0;
        return Opacity(
          opacity: enabled ? 1 : 0.5,
          child: AnimatedButton(
            width: width,
            height: 48,
            borderRadius: AppRadius.md,
            color: gradient.colors.first,
            enabled: enabled,
            onPressed: onTap,
            child: Container(
              width: width,
              height: 48,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              alignment: Alignment.center,
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : PText(
                      label,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        );
      },
    );
  }
}
