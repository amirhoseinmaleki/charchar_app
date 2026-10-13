import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ad_reward_provider.dart';
import '../providers/remote_config_provider.dart';
import '../providers/sound_provider.dart';
import '../providers/splash_provider.dart';
import '../services/security_service.dart';
import '../theme/app_images.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../widgets/cartoon_progress_bar.dart';
import '../widgets/floating_letters_background.dart';
import '../widgets/gradient_button.dart';
import '../widgets/p_text.dart';

/// The very first screen: loads everything the rest of the app assumes is
/// already available before it ever redirects onward — the restored auth
/// session (nickname/coins/avatar via GET /auth/me, see AuthController) and
/// the backend-served config (GET /config/client, see RemoteConfigProvider):
/// third-party SDK keys plus a de-facto "is the backend reachable" check.
///
/// The router holds the app on `/splash` until the session restore has
/// resolved AND that config fetch has succeeded. If the fetch fails
/// (backend down / no network) this screen shows a retry instead of letting
/// a broken app through.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Auth-session restore already starts itself in AuthController's
    // constructor (see auth_provider.dart); the gift-box status fetch
    // starts in GiftBoxController's constructor / on token change. This
    // kicks off the config fetch alongside them so all three run
    // concurrently.
    Future.microtask(() async {
      if (!mounted) return;
      final safe = await SecurityService.verifyDeviceIntegrity(context);
      if (!safe || !mounted) return;

      ref.read(remoteConfigProvider.notifier).load();
      ref.read(giftBoxControllerProvider); // ensure it's constructed early
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;
    final configStatus = ref.watch(remoteConfigProvider.select((s) => s.status));
    final failed = configStatus == RemoteConfigStatus.failed;
    final ready = ref.watch(splashReadyProvider);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: FloatingLettersBackground(color: gameTheme.heroGradient.colors.first),
          ),
          // Logo, centred.
          Center(
            child: Image.asset(
              AppImages.logo,
              width: MediaQuery.of(context).size.width * 0.55,
              fit: BoxFit.contain,
            ),
          ),
          // Progress bar (or the retry state) pinned to the bottom.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.xxl,
              ),
              child: failed
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PText(
                          'اتصال به سرور برقرار نشد.\nاینترنت خود را بررسی کنید.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          width: 200,
                          child: GradientButton(
                            label: 'تلاش دوباره',
                            onTap: () {
                              ref.read(soundServiceProvider).playButtonClick();
                              ref.read(remoteConfigProvider.notifier).load();
                            },
                          ),
                        ),
                      ],
                    )
                  : CartoonProgressBar(ready: ready),
            ),
          ),
        ],
      ),
    );
  }
}
