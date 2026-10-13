import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/sound_provider.dart';
import '../theme/app_images.dart';
import '../theme/app_spacing.dart';
import '../utils/persian_numbers.dart';
import '../widgets/app_back_button.dart';
import '../widgets/cartoon_slider.dart';
import '../widgets/cartoon_switch.dart';
import '../widgets/floating_letters_background.dart';
import '../widgets/gradient_button.dart';
import '../widgets/p_text.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soundEnabled = ref.watch(soundEnabledProvider);
    final musicVolume = ref.watch(musicVolumeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const PText('تنظیمات'),
        leading: const AppBackButton(),
      ),
      body: LetteredBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              _SectionLabel('صدا'),
              const SizedBox(height: AppSpacing.sm),
              _CartoonCard(
                child: Row(
                  children: [
                    _CardIcon(AppImages.sound),
                    const SizedBox(width: AppSpacing.md),
                    const Expanded(child: PText('صدا و موزیک')),
                    CartoonSwitch(
                      value: soundEnabled,
                      onChanged: (value) {
                        ref
                            .read(soundEnabledProvider.notifier)
                            .setEnabled(value);
                        if (value) {
                          ref.read(soundServiceProvider).playButtonClick();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _MusicVolumeTile(
                enabled: soundEnabled,
                volume: musicVolume,
                onChanged: (v) =>
                    ref.read(musicVolumeProvider.notifier).setVolume(v),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _SectionLabel('حساب کاربری'),
              const SizedBox(height: AppSpacing.md),
              GradientButton(
                label: 'خروج از حساب',
                gradient: const LinearGradient(
                  colors: [Color(0xFFE53935), Color(0xFFC62828)],
                ),
                onTap: () {
                  ref.read(soundServiceProvider).playButtonClick();
                  ref.read(authControllerProvider.notifier).logout();
                  context.go('/login');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card holding the cartoon volume slider for the background music.
class _MusicVolumeTile extends StatelessWidget {
  const _MusicVolumeTile({
    required this.enabled,
    required this.volume,
    required this.onChanged,
  });

  final bool enabled;
  final double volume;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final percent = (volume * 100).round();
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: _CartoonCard(
        bottomPadding: AppSpacing.lg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CardIcon(AppImages.music),
                const SizedBox(width: AppSpacing.md),
                const Expanded(child: PText('صدای موزیک پس‌زمینه')),
                PText('٪${percent.toPersianString()}'),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            IgnorePointer(
              ignoring: !enabled,
              child: CartoonSlider(
                value: volume,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A chunky dark card with a thick violet outline — the shared shell for
/// the cartoon-styled settings rows.
class _CartoonCard extends StatelessWidget {
  const _CartoonCard({required this.child, this.bottomPadding});

  final Widget child;
  final double? bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        bottomPadding ?? AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2140),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: const Color(0xFF4A3A6E), width: 3),
      ),
      child: child,
    );
  }
}

/// A settings-row PNG icon, sized and lightly dropped-shadowed.
class _CardIcon extends StatelessWidget {
  const _CardIcon(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Image.asset(asset, width: 28, height: 28);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return PText(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

