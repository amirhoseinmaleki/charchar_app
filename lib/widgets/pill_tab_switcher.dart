import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sound_provider.dart';
import '../theme/app_spacing.dart';
import './p_text.dart';

class PillTab {
  const PillTab({this.icon, required this.label});

  /// Optional — when null the tab shows just its label (no leading icon).
  final IconData? icon;
  final String label;
}

/// Blue palette for the switcher — a cool counterpoint to the app's
/// violet/magenta hero gradient, kept in the same family so it still reads
/// as part of the set. Same values across every screen that uses the pill.
class _PillColors {
  static const track = Color(0xFF2E3A73); // dark blue trough behind the tabs
  static const trackBorder = Color(0xFF5468C4); // thin lighter-blue outline
  static const activeTop = Color(0xFF5B8DEF); // active tab gradient (top)
  static const activeBottom = Color(0xFF3F5BD8); // active tab gradient (bottom)
  static const activeBorder = Color(0xFF7EA6FF); // active tab highlight edge
  static const inactiveText = Color(0xFFB9C4EE); // muted blue-white for idle tabs
  static const divider = Color(0x99161E44); // dark vertical seam between tabs, reads on both track and pill
}

/// The segmented pill switcher first built for "بازی با دوستان" (create/join
/// room), generalized to any number of tabs so Shop and Leaderboard can use
/// the exact same visual language instead of the default Material [TabBar]
/// underline style.
class PillTabSwitcher extends StatelessWidget {
  const PillTabSwitcher({super.key, required this.controller, required this.tabs});

  final TabController controller;
  final List<PillTab> tabs;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller.animation ?? controller,
      builder: (context, _) {
        final raw = controller.animation?.value ?? controller.index.toDouble();
        final t = raw.clamp(0.0, (tabs.length - 1).toDouble());

        return Container(
          height: 52,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _PillColors.track,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: _PillColors.trackBorder),
          ),
          // LayoutBuilder wraps the whole Stack so every Positioned below is
          // a *direct* child of a Stack (a Positioned attached to anything
          // else — e.g. straight under a LayoutBuilder — throws a
          // StackParentData error during layout).
          //
          // The pill uses a plain Positioned, not AnimatedPositioned: the
          // enclosing AnimatedBuilder already rebuilds this every frame with
          // an interpolated `t` from the TabController's own animation.
          // Stacking an implicit AnimatedPositioned on top of that ran two
          // animations against the same value and made tab taps stutter/hang.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final segmentWidth = constraints.maxWidth / tabs.length;
              // `Positioned.directional` so the pill and the dividers are
              // measured from the *start* edge (right, under RTL) — matching
              // how the Row lays the tabs out. A plain `left:` offset put the
              // pill on the wrong tab in RTL, so tapping "این ماه" landed on
              // "همه زمان‌ها".
              final textDirection = Directionality.of(context);
              return Stack(
                children: [
                  Positioned.directional(
                    textDirection: textDirection,
                    start: t * segmentWidth,
                    top: 0,
                    bottom: 0,
                    width: segmentWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [_PillColors.activeTop, _PillColors.activeBottom],
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: _PillColors.activeBorder),
                        boxShadow: const [
                          BoxShadow(color: Color(0x553F5BD8), blurRadius: 8, offset: Offset(0, 2)),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < tabs.length; i++)
                        Expanded(
                          child: _PillTabItem(
                            icon: tabs[i].icon,
                            label: tabs[i].label,
                            isActive: (t.round()) == i,
                            onTap: () => controller.animateTo(i),
                          ),
                        ),
                    ],
                  ),
                  // Vertical rules between tabs, painted on top of everything
                  // so they read as a clear seam between segments — including
                  // where one meets the active pill (matching the reference).
                  for (var i = 1; i < tabs.length; i++)
                    Positioned.directional(
                      textDirection: textDirection,
                      start: i * segmentWidth - 1,
                      top: 5,
                      bottom: 5,
                      child: Container(
                        width: 2,
                        decoration: BoxDecoration(
                          color: _PillColors.divider,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _PillTabItem extends ConsumerWidget {
  const _PillTabItem({this.icon, required this.label, required this.isActive, required this.onTap});

  final IconData? icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = isActive ? Colors.white : _PillColors.inactiveText;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () {
          ref.read(soundServiceProvider).playButtonClick();
          onTap();
        },
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: AppSpacing.xs),
              ],
              Flexible(
                child: PText(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: color,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
