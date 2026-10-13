import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/category.dart';
import '../providers/auth_provider.dart';
import '../providers/room_provider.dart';
import '../providers/round_provider.dart';
import '../providers/sound_provider.dart';
import '../theme/app_images.dart';
import '../theme/app_spacing.dart';
import '../utils/persian_numbers.dart';
import '../widgets/coin_pill.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/countdown_ring.dart';
import '../widgets/error_dialog.dart';
import '../widgets/floating_letters_background.dart';
import '../widgets/gradient_button.dart';
import '../widgets/p_text.dart';
import '../widgets/timeout_bonus_dialog.dart';

class RoundScreen extends ConsumerStatefulWidget {
  const RoundScreen({super.key, required this.roomCode});

  final String roomCode;

  @override
  ConsumerState<RoundScreen> createState() => _RoundScreenState();
}

class _RoundScreenState extends ConsumerState<RoundScreen> {
  final Map<CategoryId, TextEditingController> _controllers = {};
  int? _controllersForRound;
  bool _hasSubmitted = false;
  bool _isUsingHint = false;
  bool _isUsingExtraTime = false;
  bool _isShowingTimeoutDialog = false;

  TextEditingController _controllerFor(CategoryId category) {
    return _controllers.putIfAbsent(category, () => TextEditingController());
  }

  void _ensureControllersForRound(int roundIndex, List<CategoryId> categories) {
    if (_controllersForRound == roundIndex) return;
    _controllersForRound = roundIndex;
    _hasSubmitted = false;
    _isShowingTimeoutDialog = false;
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    for (final category in categories) {
      _controllers[category] = TextEditingController();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(soundServiceProvider).playGameStart();
    });
  }

  int _currentHintCost(int hintsUsed) {
    if (hintsUsed == 0) return 300;
    if (hintsUsed == 1) return 600;
    return 1200;
  }

  Future<void> _handleUseHint() async {
    final roundState = ref.read(roundControllerProvider);
    final hintsUsed = roundState.hintsUsedInRound;
    if (_hasSubmitted || _isUsingHint || hintsUsed >= 3) return;

    final cost = _currentHintCost(hintsUsed);
    final myCoins = ref.read(authControllerProvider).player?.coinBalance ?? 0;
    if (myCoins < cost) {
      ErrorDialog.show(
        context,
        'برای دریافت راهنما حداقل به ${cost.toPersianString()} سکه نیاز دارید.',
        title: 'سکه ناکافی',
      );
      return;
    }

    setState(() => _isUsingHint = true);
    ref.read(soundServiceProvider).playButtonClick();

    try {
      // Find the first empty category or let server pick
      CategoryId? targetCat;
      final round = roundState.currentRound;
      if (round != null) {
        for (final cat in round.categories) {
          if ((_controllers[cat]?.text.trim() ?? '').isEmpty) {
            targetCat = cat;
            break;
          }
        }
      }

      final result = await ref
          .read(roundControllerProvider.notifier)
          .requestHint(widget.roomCode, category: targetCat);

      if (!mounted) return;
      if (result != null && result['success'] == true) {
        final catWire = result['category'] as String?;
        final word = result['word'] as String?;
        if (catWire != null && word != null && word.isNotEmpty) {
          final catId = CategoryIdX.fromWire(catWire);
          _controllerFor(catId).text = word;
          ref.read(soundServiceProvider).playCoinCollect();
        }
      } else {
        final msg = result?['message'] as String? ?? 'خطا در دریافت راهنما.';
        ErrorDialog.show(context, msg, title: 'راهنما');
      }
    } finally {
      if (mounted) setState(() => _isUsingHint = false);
    }
  }

  Future<void> _handleUseExtraTime() async {
    final roundState = ref.read(roundControllerProvider);
    if (_hasSubmitted || _isUsingExtraTime || roundState.extraTimeUsed) return;

    final myCoins = ref.read(authControllerProvider).player?.coinBalance ?? 0;
    if (myCoins < 300) {
      ErrorDialog.show(
        context,
        'برای دریافت زمان اضافه حداقل به ۳۰۰ سکه نیاز دارید.',
        title: 'سکه ناکافی',
      );
      return;
    }

    setState(() => _isUsingExtraTime = true);
    ref.read(soundServiceProvider).playButtonClick();

    try {
      final success = await ref
          .read(roundControllerProvider.notifier)
          .requestExtraTime(widget.roomCode);

      if (!mounted) return;
      if (success) {
        ref.read(soundServiceProvider).playCoinCollect();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: PText('۲۰ ثانیه زمان اضافه دریافت شد! ⏰'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ErrorDialog.show(
          context,
          'در هر دست فقط یک‌بار می‌توانید از زمان اضافه استفاده کنید.',
          title: 'زمان اضافه',
        );
      }
    } finally {
      if (mounted) setState(() => _isUsingExtraTime = false);
    }
  }

  Future<void> _handleTimerExpired() async {
    if (_hasSubmitted) return;

    final roundState = ref.read(roundControllerProvider);
    // If timeout bonus not used yet, offer the ad dialog
    if (!roundState.timeoutBonusUsed && !_isShowingTimeoutDialog && mounted) {
      setState(() => _isShowingTimeoutDialog = true);
      final grant = await TimeoutBonusDialog.show(context, roomCode: widget.roomCode);
      if (mounted) setState(() => _isShowingTimeoutDialog = false);

      if (grant != null && grant['success'] == true && mounted) {
        // Bonus applied! Fill hint if provided
        final hint = grant['hint'];
        if (hint is Map) {
          final catWire = hint['category'] as String?;
          final word = hint['word'] as String?;
          if (catWire != null && word != null && word.isNotEmpty) {
            final catId = CategoryIdX.fromWire(catWire);
            _controllerFor(catId).text = word;
          }
        }
        return; // countdown will continue with the updated newDeadline
      }
    }

    _submit();
  }

  void _submit() {
    if (_hasSubmitted) return;
    final answers = {
      for (final entry in _controllers.entries)
        entry.key: entry.value.text.trim(),
    };
    ref
        .read(roundControllerProvider.notifier)
        .submitAnswers(widget.roomCode, answers);
    setState(() => _hasSubmitted = true);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roundState = ref.watch(roundControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final round = roundState.currentRound;

    ref.listen(roundControllerProvider, (previous, next) {
      if (previous?.phase != RoundPhase.voting &&
          next.phase == RoundPhase.voting) {
        context.go('/vote', extra: widget.roomCode);
      } else if (previous?.phase != RoundPhase.result &&
          next.phase == RoundPhase.result) {
        context.go('/round-result', extra: widget.roomCode);
      }
    });

    if (round == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _ensureControllersForRound(round.roundIndex, round.categories);
    final isWaiting =
        roundState.phase == RoundPhase.waitingForOthers || _hasSubmitted;

    final screenHeight = MediaQuery.of(context).size.height;
    final ringSize = (screenHeight < 700) ? 135.0 : ((screenHeight < 800) ? 160.0 : 190.0);
    final letterFontSize = (screenHeight < 700) ? 40.0 : ((screenHeight < 800) ? 48.0 : 58.0);

    final hintsUsed = roundState.hintsUsedInRound;
    final extraTimeUsed = roundState.extraTimeUsed;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await ConfirmDialog.show(
          context,
          title: 'خروج از بازی؟',
          message: 'در صورت خروج، از بازی فعلی خارج شده و به صفحه اصلی می‌روید.',
          confirmLabel: 'خروج از بازی',
        );
        if (leave == true && context.mounted) {
          ref.read(roundControllerProvider.notifier).reset();
          ref.read(roomControllerProvider.notifier).leaveRoom();
          context.go('/');
        }
      },
      child: Scaffold(
        body: LetteredBackdrop(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  // Top Header Row: Coin Pill on Right (RTL leading), Power-ups on Left (RTL trailing)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Right: Coin balance
                      CoinPill(
                        balance: auth.player?.coinBalance,
                        compact: true,
                        animated: false,
                      ),
                      // Left: In-game helpers (Lamp & Stopwatch)
                      if (!isWaiting)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. Extra Time Stopwatch
                            _StopwatchButton(
                              used: extraTimeUsed,
                              isLoading: _isUsingExtraTime,
                              onTap: _handleUseExtraTime,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            // 2. Hint Lightbulb
                            _LightbulbButton(
                              hintsUsed: hintsUsed,
                              isLoading: _isUsingHint,
                              onTap: _handleUseHint,
                            ),
                          ],
                        )
                      else
                        const SizedBox.shrink(),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  CountdownRing(
                    size: ringSize,
                    strokeWidth: ringSize < 150 ? 10 : 14,
                    deadline: round.localDeadline,
                    totalDurationMs: round.remainingMsAtReceipt,
                    onExpired: _handleTimerExpired,
                    onTwelveSecondsLeft: () =>
                        ref.read(soundServiceProvider).playTimerWarning(),
                    child: PText(
                      round.letter,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: letterFontSize,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight < 700 ? AppSpacing.xs : AppSpacing.sm),
                  if (isWaiting)
                    Expanded(
                      child: _WaitingForOthers(
                        submittedCount: roundState.submittedPlayerIds.length,
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        children: [
                          for (final category in round.categories)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: _CategoryField(
                                category: category,
                                controller: _controllerFor(category),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (!isWaiting) ...[
                    const SizedBox(height: AppSpacing.sm),
                    GradientButton(label: 'ثبت پاسخ‌ها', onTap: _submit),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lightbulb Hint Button: 3D Game Capsule style with gold badge and pulsing lamp
class _LightbulbButton extends StatelessWidget {
  const _LightbulbButton({
    required this.hintsUsed,
    required this.isLoading,
    required this.onTap,
  });

  final int hintsUsed;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final canUse = hintsUsed < 3;
    final remainingCount = 3 - hintsUsed;
    final cost = hintsUsed == 0
        ? 300
        : hintsUsed == 1
            ? 600
            : 1200;

    Widget icon = Image.asset(AppImages.lightBulb, width: 28, height: 28);
    if (canUse && !isLoading) {
      icon = icon
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 650.ms, curve: Curves.easeInOut);
    }

    return GestureDetector(
      onTap: (canUse && !isLoading) ? onTap : null,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: canUse
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF43301B), Color(0xFF281C10)],
                )
              : const LinearGradient(
                  colors: [Color(0xFF231C2E), Color(0xFF191422)],
                ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: canUse ? const Color(0xFFF5C542) : const Color(0xFF3E3354),
            width: 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              offset: const Offset(0, 3),
              blurRadius: 4,
            ),
            if (canUse)
              BoxShadow(
                color: const Color(0xFFF5C542).withValues(alpha: 0.25),
                blurRadius: 8,
                spreadRadius: 0,
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF5C542)),
              )
            else
              icon,
            const SizedBox(width: 6),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: canUse ? const Color(0xFFF5C542) : Colors.white12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: PText(
                    canUse ? '${remainingCount.toPersianString()} بار' : 'تمام شد',
                    style: TextStyle(
                      color: canUse ? const Color(0xFF241500) : Colors.white38,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ),
                if (canUse) ...[
                  const SizedBox(height: 1),
                  PText(
                    '${cost.toPersianString()} سکه',
                    style: const TextStyle(
                      color: Color(0xFFFFE082),
                      fontWeight: FontWeight.w800,
                      fontSize: 9,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Stopwatch Extra Time Button: 3D Game Capsule style with cyan badge and shaking stopwatch
class _StopwatchButton extends StatelessWidget {
  const _StopwatchButton({
    required this.used,
    required this.isLoading,
    required this.onTap,
  });

  final bool used;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget icon = Image.asset(AppImages.stopWatch, width: 28, height: 28);
    if (!used && !isLoading) {
      icon = icon
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .shake(duration: 900.ms, hz: 3);
    }

    return GestureDetector(
      onTap: (!used && !isLoading) ? onTap : null,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: !used
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1B354C), Color(0xFF0F2030)],
                )
              : const LinearGradient(
                  colors: [Color(0xFF231C2E), Color(0xFF191422)],
                ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: !used ? const Color(0xFF38BDF8) : const Color(0xFF3E3354),
            width: 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              offset: const Offset(0, 3),
              blurRadius: 4,
            ),
            if (!used)
              BoxShadow(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                blurRadius: 8,
                spreadRadius: 0,
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
              )
            else
              icon,
            const SizedBox(width: 6),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: !used ? const Color(0xFF38BDF8) : Colors.white12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: PText(
                    !used ? '+۲۰ ثانیه' : 'استفاده شد',
                    style: TextStyle(
                      color: !used ? const Color(0xFF072136) : Colors.white38,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ),
                if (!used) ...[
                  const SizedBox(height: 1),
                  const PText(
                    '۳۰۰ سکه',
                    style: TextStyle(
                      color: Color(0xFFBAE6FD),
                      fontWeight: FontWeight.w800,
                      fontSize: 9,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A chunky, cartoon-style answer field: a rounded dark pill with a thick
/// outline that brightens to the game accent while focused. The category
/// name + icon sit at the trailing (visual right, RTL) edge as a label.
class _CategoryField extends StatefulWidget {
  const _CategoryField({required this.category, required this.controller});

  final CategoryId category;
  final TextEditingController controller;

  @override
  State<_CategoryField> createState() => _CategoryFieldState();
}

class _CategoryFieldState extends State<_CategoryField> {
  final _focusNode = FocusNode();

  static const _fill = Color(0xFF2A2140);
  static const _outline = Color(0xFF4A3A6E);

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final focused = _focusNode.hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: focused ? accent : _outline, width: 3),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          // Leading (right, in RTL): the category icon + name.
          Icon(
            widget.category.icon,
            size: 20,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          const SizedBox(width: AppSpacing.sm),
          PText(
            widget.category.labelFa,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // The answer field fills the rest; text flows right-to-left.
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingForOthers extends StatelessWidget {
  const _WaitingForOthers({required this.submittedCount});

  final int submittedCount;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(AppImages.hourglass, width: 56, height: 56),
          const SizedBox(height: AppSpacing.lg),
          PText('منتظر بقیه...', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          PText(
            '${submittedCount.toPersianString()} نفر ثبت کردند',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
