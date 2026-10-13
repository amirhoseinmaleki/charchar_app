import 'package:animated_button/animated_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/ad_reward_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/remote_config_provider.dart';
import '../providers/sound_provider.dart';
import '../models/ad_reward.dart';
import '../services/ad_service.dart';
import '../theme/app_images.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import './p_text.dart';

/// Shown when an action (بازی آنلاین، ساخت/ورود اتاق) is rejected for
/// `INSUFFICIENT_COINS`. Instead of a dead end, it offers a rewarded ad
/// for free coins.
///
/// This is deliberately **independent of the Home gift box's cooldown /
/// daily cap**: when the player is at 0 coins and can't otherwise play,
/// the ad is always available. It calls [AdService]/[AdRewardService]
/// directly rather than going through [giftBoxControllerProvider] (whose
/// `watchAd` gates on `status.canWatch`).
///
/// [show] resolves to `true` when an ad was watched and coins were
/// granted — the caller should then fire its own coin-burst animation and
/// may retry the original action.
class InsufficientCoinsDialog extends ConsumerStatefulWidget {
  const InsufficientCoinsDialog({super.key, required this.message});

  /// The server-built "سکه کافی ندارید. نیاز: …, موجودی: …" line.
  final String message;

  static Future<bool?> show(BuildContext context, String message) {
    // showGeneralDialog (not showDialog) so the dialog scales + fades in
    // with a slight overshoot rather than just appearing.
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, a, b) => InsufficientCoinsDialog(message: message),
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
  ConsumerState<InsufficientCoinsDialog> createState() => _InsufficientCoinsDialogState();
}

class _InsufficientCoinsDialogState extends ConsumerState<InsufficientCoinsDialog> {
  bool _busy = false;
  String? _adError;

  Future<void> _watchAd() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _adError = null;
    });
    ref.read(soundServiceProvider).playButtonClick();

    final token = ref.read(authControllerProvider).token;
    if (token == null) {
      if (mounted) {
        setState(() {
          _busy = false;
          _adError = 'نشست شما نامعتبر است. دوباره وارد شوید.';
        });
      }
      return;
    }

    final remoteConfig = ref.read(remoteConfigValueProvider);
    final result = await ref.read(adServiceProvider).watchRewardedAd(remoteConfig);
    if (kDebugMode) debugPrint('[InsufficientCoins] watchRewardedAd -> $result');
    if (!mounted) return;

    if (result != AdWatchResult.rewarded) {
      setState(() {
        _busy = false;
        _adError = result == AdWatchResult.closedWithoutReward
            ? 'برای دریافت جایزه باید تبلیغ را تا انتها تماشا کنید.'
            : 'در حال حاضر تبلیغی برای نمایش موجود نیست. کمی بعد دوباره امتحان کنید.';
      });
      return;
    }

    try {
      // The rescue grant — separate endpoint / quota from the Home gift
      // box (POST /ads/reward). Gated server-side on coinBalance < 100.
      final claim = await ref.read(adRewardServiceProvider).claimRescueReward(token);
      if (kDebugMode) {
        debugPrint('[InsufficientCoins] rescue claim OK: +${claim.status.coinAmount}, balance=${claim.coinBalance}');
      }
      ref.read(authControllerProvider.notifier).updateCoinBalance(claim.coinBalance);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AdRewardException catch (e) {
      if (kDebugMode) debugPrint('[InsufficientCoins] rescue claim FAILED: ${e.code} / ${e.message}');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _adError = e.code == 'AD_RESCUE_NOT_ELIGIBLE'
            ? 'موجودی‌ات برای این جایزه کافی است. از جعبهٔ هدیه یا فروشگاه استفاده کن.'
            : e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;

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
            PText('سکه کافی نداری', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),

            if (_adError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              PText(
                _adError!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: gameTheme.invalidColor),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),

            _DialogButton(
              label: _busy ? 'در حال بارگذاری…' : 'تماشای تبلیغ',
              gradient: gameTheme.baseGradient,
              enabled: !_busy,
              busy: _busy,
              onTap: _watchAd,
            ),
            const SizedBox(height: AppSpacing.sm),
            _DialogButton(
              label: 'خرید سکه',
              gradient: const LinearGradient(colors: [Color(0xFFF5C542), Color(0xFFE0A21E)]),
              enabled: !_busy,
              onTap: () {
                ref.read(soundServiceProvider).playButtonClick();
                // Grab the router before popping — this route's context is
                // defunct the moment the dialog closes.
                final router = GoRouter.of(context);
                Navigator.of(context).pop(false);
                router.push('/shop', extra: const {'tab': 'coins'});
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            _DialogButton(
              label: 'بی‌خیال',
              gradient: LinearGradient(colors: [gameTheme.invalidColor, gameTheme.invalidColor]),
              enabled: !_busy,
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
  const _DialogButton({
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

  static const _height = 48.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth && constraints.maxWidth.isFinite ? constraints.maxWidth : 200.0;
        return Opacity(
          opacity: enabled ? 1 : 0.5,
          child: AnimatedButton(
            width: width,
            height: _height,
            borderRadius: AppRadius.sm,
            color: gradient.colors.first,
            enabled: enabled,
            onPressed: onTap,
            child: Container(
              width: width,
              height: _height,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(AppRadius.sm),
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
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        );
      },
    );
  }
}
