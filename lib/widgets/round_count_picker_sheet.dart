import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/remote_config_provider.dart';
import '../providers/sound_provider.dart';
import '../theme/app_spacing.dart';
import '../utils/persian_numbers.dart';
import '../widgets/coin_pill.dart';
import '../widgets/gradient_button.dart';
import './p_text.dart';

/// Bottom sheet letting the player pick how many rounds the online game
/// should run for before it's created. The max comes from the server's
/// `timing.roundsPerGame` (`GET /config/client`). Returns the chosen count,
/// or null if dismissed without confirming.
Future<int?> showRoundCountPickerSheet(BuildContext context, {required int coinCost}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => _RoundCountPickerSheet(coinCost: coinCost),
  );
}

class _RoundCountPickerSheet extends ConsumerStatefulWidget {
  const _RoundCountPickerSheet({required this.coinCost});

  final int coinCost;

  @override
  ConsumerState<_RoundCountPickerSheet> createState() => _RoundCountPickerSheetState();
}

class _RoundCountPickerSheetState extends ConsumerState<_RoundCountPickerSheet> {
  static const _sheetFill = Color(0xFF221B33);
  static const _outline = Color(0xFF4A3A6E);
  static const _cardFill = Color(0xFF2A2140);

  int _selected = 3;

  @override
  Widget build(BuildContext context) {
    // How many round-count chips to offer. Server-driven, clamped to a
    // range the row can actually lay out; the initial selection is pulled
    // back inside the range if the server ever lowers the max.
    final maxRounds = ref
        .watch(remoteConfigValueProvider.select((c) => c.config.timing.roundsPerGame))
        .clamp(1, 9);
    if (_selected > maxRounds) _selected = maxRounds;
    return Container(
      decoration: const BoxDecoration(
        color: _sheetFill,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: _outline, width: 3),
          left: BorderSide(color: _outline, width: 3),
          right: BorderSide(color: _outline, width: 3),
        ),
        boxShadow: [
          BoxShadow(color: Color(0x66000000), blurRadius: 20, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.md,
            AppSpacing.screenPadding,
            AppSpacing.screenPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Chunky grab handle.
              Center(
                child: Container(
                  width: 44,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _outline,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              PText(
                'بازی آنلاین',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: AppSpacing.xs),
              PText(
                'تعداد دورهای بازی را انتخاب کنید',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var count = 1; count <= maxRounds; count++)
                    _RoundCountChip(
                      count: count,
                      isSelected: count == _selected,
                      onTap: () => setState(() => _selected = count),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: _cardFill,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: _outline, width: 3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    PText(
                      'هزینه بازی',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    CoinPill(balance: widget.coinCost),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              GradientButton(
                label: 'شروع بازی',
                onTap: () => Navigator.of(context).pop(_selected),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A chunky, cartoon-style circular round-count chip: a thick dark-outlined
/// disc that's dark-grey when unselected and a glossy golden dome (with a
/// quick scale bounce) when selected. Matches CartoonSwitch / CartoonSlider.
class _RoundCountChip extends ConsumerStatefulWidget {
  const _RoundCountChip({
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  ConsumerState<_RoundCountChip> createState() => _RoundCountChipState();
}

class _RoundCountChipState extends ConsumerState<_RoundCountChip>
    with SingleTickerProviderStateMixin {
  static const _gold = Color(0xFFF5C542);
  static const _goldDeep = Color(0xFFE0A21E);
  static const _goldLight = Color(0xFFFFE9A8);
  static const _fillOff = Color(0xFF2A2140);
  static const _outline = Color(0xFF4A3A6E);
  static const _outlineOn = Color(0xFF6E4E12);

  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scale = Tween<double>(begin: 1, end: 0.82).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    ref.read(soundServiceProvider).playButtonClick();
    await _controller.forward();
    await _controller.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.isSelected;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_goldLight, _gold, _goldDeep],
                    stops: [0.0, 0.5, 1.0],
                  )
                : null,
            color: selected ? null : _fillOff,
            border: Border.all(
              color: selected ? _outlineOn : _outline,
              width: 3,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x66F5C542),
                      blurRadius: 10,
                      spreadRadius: -1,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            widget.count.toPersianString(),
            style: TextStyle(
              color: selected ? _outlineOn : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 19,
            ),
          ),
        ),
      ),
    );
  }
}
