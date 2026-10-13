import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sound_provider.dart';
import '../theme/app_images.dart';
import '../theme/app_spacing.dart';
import '../utils/persian_numbers.dart';
import './p_text.dart';

/// Shows the player's coin balance as a pill — used on Home, Shop, and
/// anywhere else the balance needs to stay visible. Null balance renders a
/// placeholder dash rather than "0" so it's clear the value hasn't loaded
/// yet vs. genuinely being zero.
///
/// [animated] gives the pill a fixed height and makes the whole pill
/// tappable, for spots where tapping it does something (e.g. the Home
/// screen, where it opens the shop). A tap on any tappable pill plays the
/// shared click sound and a quick shrink-and-return scale bounce (same as
/// the Home screen's round icon buttons) before running [onTap].
class CoinPill extends ConsumerStatefulWidget {
  const CoinPill({
    super.key,
    required this.balance,
    this.onTap,
    this.animated = false,
    this.compact = false,
  });

  final int? balance;
  final VoidCallback? onTap;
  final bool animated;

  /// A smaller variant for the Home header, where the pill shares a row
  /// with the gift box and doesn't need to be the visual anchor it is on
  /// the shop screen.
  final bool compact;

  static const _height = 54.0;
  static const _compactHeight = 42.0;
  static const _radius = 14.0;

  @override
  ConsumerState<CoinPill> createState() => _CoinPillState();
}

class _CoinPillState extends ConsumerState<CoinPill>
    with TickerProviderStateMixin {
  late final AnimationController _tapController;
  late final Animation<double> _scale;

  // Pulse effect when coins increase or decrease
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  int _previousBalance = 0;
  bool _isGain = true;

  @override
  void initState() {
    super.initState();
    _previousBalance = widget.balance ?? 0;

    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scale = Tween<double>(begin: 1, end: 0.82).animate(
      CurvedAnimation(
        parent: _tapController,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeOutBack,
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.14).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.14, end: 0.96).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.96, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 30,
      ),
    ]).animate(_pulseController);
  }

  @override
  void didUpdateWidget(CoinPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldVal = oldWidget.balance;
    final newVal = widget.balance;

    if (oldVal != null && newVal != null && oldVal != newVal) {
      _previousBalance = oldVal;
      _isGain = newVal > oldVal;
      _pulseController.forward(from: 0.0);
    } else if (newVal != null && oldVal == null) {
      _previousBalance = newVal;
    }
  }

  @override
  void dispose() {
    _tapController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    ref.read(soundServiceProvider).playButtonClick();
    await _tapController.forward();
    await _tapController.reverse();
    if (!mounted) return;
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final animated = widget.animated;
    final currentBalance = widget.balance;

    const goldGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF7D774), Color(0xFFE0A93B), Color(0xFFC8871F)],
    );

    final coinSize = compact ? 28.0 : 40.0;
    final numberStyle = (compact
            ? Theme.of(context).textTheme.titleMedium
            : Theme.of(context).textTheme.titleLarge)
        ?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w800,
      shadows: const [
        Shadow(color: Color(0x66000000), offset: Offset(0, 1), blurRadius: 2),
      ],
    );

    Widget buildNumberDisplay() {
      if (currentBalance == null) {
        return PText('—', style: numberStyle);
      }

      return TweenAnimationBuilder<double>(
        tween: Tween<double>(
          begin: _previousBalance.toDouble(),
          end: currentBalance.toDouble(),
        ),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder: (context, animatedValue, child) {
          final rounded = animatedValue.round();
          return PText(
            rounded.toPersianStringGrouped(),
            style: numberStyle,
          );
        },
      );
    }

    final content = AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scaleVal = _pulseController.isAnimating ? _pulseScale.value : 1.0;
        final borderColor = _pulseController.isAnimating
            ? (_isGain ? const Color(0xFF81C784) : const Color(0xFFE57373))
            : const Color(0xFFB0741A);
        final borderWidth = _pulseController.isAnimating ? 2.0 : 1.0;

        return Transform.scale(
          scale: scaleVal,
          child: Container(
            height: animated ? (compact ? CoinPill._compactHeight : CoinPill._height) : null,
            padding: EdgeInsets.only(
              left: AppSpacing.xs,
              right: compact ? AppSpacing.sm : AppSpacing.md,
              top: AppSpacing.xs,
              bottom: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              gradient: goldGradient,
              borderRadius: BorderRadius.circular(compact ? 12 : CoinPill._radius),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: _pulseController.isAnimating
                  ? [
                      BoxShadow(
                        color: (_isGain ? const Color(0xFF4CAF50) : const Color(0xFFE53935))
                            .withValues(alpha: 0.45 * (1.0 - _pulseController.value)),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: Row(
              textDirection: TextDirection.ltr,
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(AppImages.coin, width: coinSize, height: coinSize),
                const SizedBox(width: AppSpacing.xs),
                buildNumberDisplay(),
              ],
            ),
          ),
        );
      },
    );

    if (!animated && widget.onTap == null) return content;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: ScaleTransition(scale: _scale, child: content),
    );
  }
}
