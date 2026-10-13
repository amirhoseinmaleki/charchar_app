import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shop.dart';
import '../providers/shop_provider.dart';
import '../providers/sound_provider.dart';
import '../services/iap/store_config.dart';
import '../theme/app_images.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/name_color.dart';
import '../utils/persian_numbers.dart';
import '../widgets/app_back_button.dart';
import '../widgets/coin_burst.dart';
import '../widgets/error_dialog.dart';
import '../widgets/floating_letters_background.dart';
import '../widgets/gradient_button.dart';
import '../widgets/pill_tab_switcher.dart';
import '../widgets/player_avatar.dart';
import '../widgets/p_text.dart';
import '../widgets/tapsell_banner_ad.dart';

/// Tabs for Avatars / Name Colors / Coins — the full catalog (including
/// prices, ownership, and purchasability) is always fetched fresh from
/// `GET /shop/items`, never hardcoded client-side. Coin packs are bought
/// through the active store's IAP (Cafe Bazaar or Myket, fixed at build
/// time — see `lib/services/iap/` and `MYKET_IAP.md`).
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key, this.initialTab});

  /// Optional `?tab=` value: `avatar` | `nameColor` | `coins` (or `coinPack`).
  /// Anything else falls back to the first tab.
  final String? initialTab;

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// Wraps the coin image in the balance bar — the landing point for the
  /// post-purchase coin burst.
  final _coinBalanceKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decode the coin sprite ahead of the first burst so it doesn't spend
    // its opening frames waiting on an image load.
    precacheImage(const AssetImage(AppImages.coin), context);
  }

  /// Fires the coins-fly-to-balance animation from [from] (global coords,
  /// usually the tapped coin-pack card's centre) to the balance bar, with a
  /// one-shot coin-collect chime.
  void _fireCoinBurst(Offset from) {
    final destBox =
        _coinBalanceKey.currentContext?.findRenderObject() as RenderBox?;
    if (destBox == null || !mounted) return;
    ref.read(soundServiceProvider).playCoinCollect();
    CoinBurst.fire(
      context: context,
      from: from,
      to: destBox.localToGlobal(destBox.size.center(Offset.zero)),
    );
  }

  static const _categories = [
    ShopCategory.avatar,
    ShopCategory.nameColor,
    ShopCategory.coinPack,
  ];

  int _initialTabIndex() {
    switch (widget.initialTab) {
      case 'coins':
      case 'coinPack':
        return _categories.indexOf(ShopCategory.coinPack);
      case 'nameColor':
        return _categories.indexOf(ShopCategory.nameColor);
      case 'avatar':
        return _categories.indexOf(ShopCategory.avatar);
      default:
        return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _categories.length,
      vsync: this,
      initialIndex: _initialTabIndex(),
    );
    // Always pull a fresh catalog each time the Shop opens — reset so a
    // stale one isn't shown while the request is in flight.
    Future.microtask(() {
      final shop = ref.read(shopControllerProvider.notifier);
      shop.load(reset: true);
      // Recover any Bazaar coin-pack purchase that was paid for but never
      // credited (app killed mid-flow, earlier network failure).
      shop.restoreCoinPurchases();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shopState = ref.watch(shopControllerProvider);

    ref.listen(shopControllerProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ErrorDialog.show(context, next.error!);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const PText('فروشگاه'),
        leading: const AppBackButton(),
      ),
      body: LetteredBackdrop(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    AppSpacing.sm,
                    AppSpacing.screenPadding,
                    0,
                  ),
                  child: _CoinBalanceBar(
                    coinBalance: shopState.catalog?.coinBalance,
                    coinImageKey: _coinBalanceKey,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  child: PillTabSwitcher(
                    controller: _tabController,
                    tabs: [for (final c in _categories) PillTab(label: c.labelFa)],
                  ),
                ),
                Expanded(
                  child: shopState.isLoading && shopState.catalog == null
                      ? const Center(child: CircularProgressIndicator())
                      : shopState.catalog == null
                      ? _ErrorState(
                          onRetry: () =>
                              ref.read(shopControllerProvider.notifier).load(),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            for (final c in _categories)
                              _ShopGrid(
                                items: shopState.catalog!.items
                                    .where((i) => i.category == c)
                                    .toList(),
                                purchasingItemId: shopState.purchasingItemId,
                                onCoinPackPurchased: _fireCoinBurst,
                              ),
                          ],
                        ),
                ),
              ],
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: TapsellBannerAd(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoinBalanceBar extends StatefulWidget {
  const _CoinBalanceBar({required this.coinBalance, this.coinImageKey});

  final int? coinBalance;

  /// Keyed onto the coin sprite so a purchase burst knows where to land.
  final Key? coinImageKey;

  @override
  State<_CoinBalanceBar> createState() => _CoinBalanceBarState();
}

class _CoinBalanceBarState extends State<_CoinBalanceBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  int _previousBalance = 0;
  bool _isGain = true;

  @override
  void initState() {
    super.initState();
    _previousBalance = widget.coinBalance ?? 0;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.06).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.06, end: 0.98).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.98, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 30,
      ),
    ]).animate(_pulseController);
  }

  @override
  void didUpdateWidget(_CoinBalanceBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldVal = oldWidget.coinBalance;
    final newVal = widget.coinBalance;

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
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;
    final currentBalance = widget.coinBalance;

    Widget buildNumberDisplay() {
      if (currentBalance == null) {
        return PText(
          '—',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: gameTheme.goldColor),
        );
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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: _pulseController.isAnimating
                  ? (_isGain ? const Color(0xFF81C784) : const Color(0xFFEF5350))
                  : gameTheme.goldColor,
              fontWeight: FontWeight.w800,
            ),
          );
        },
      );
    }

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scaleVal = _pulseController.isAnimating ? _pulseScale.value : 1.0;
        return Transform.scale(
          scale: scaleVal,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  gameTheme.goldColor.withValues(alpha: _pulseController.isAnimating ? 0.35 : 0.22),
                  gameTheme.goldColor.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: _pulseController.isAnimating
                  ? Border.all(
                      color: _isGain ? const Color(0xFF81C784) : const Color(0xFFE57373),
                      width: 1.5,
                    )
                  : null,
            ),
            child: Row(
              children: [
                KeyedSubtree(
                  key: widget.coinImageKey,
                  child: Image.asset(AppImages.coin, width: 28, height: 28),
                ),
                const SizedBox(width: AppSpacing.sm),
                buildNumberDisplay(),
                const Spacer(),
                PText('موجودی سکه', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ShopGrid extends StatelessWidget {
  const _ShopGrid({
    required this.items,
    required this.purchasingItemId,
    this.onCoinPackPurchased,
  });

  final List<ShopItem> items;
  final String? purchasingItemId;

  /// Called after a coin-pack purchase succeeds, with the global-coords
  /// centre of the tapped card — the origin for the coin-fly animation.
  final void Function(Offset from)? onCoinPackPurchased;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: PText(
          'آیتمی در این بخش موجود نیست.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.82,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _ShopItemCard(
              item: item,
              isPurchasing: purchasingItemId == item.id,
              onCoinPackPurchased: onCoinPackPurchased,
            )
            .animate()
            .fadeIn(duration: 250.ms, delay: (30 * index).ms)
            .scale(
              begin: const Offset(0.94, 0.94),
              end: const Offset(1, 1),
              duration: 250.ms,
              delay: (30 * index).ms,
            );
      },
    );
  }
}

class _ShopItemCard extends ConsumerWidget {
  const _ShopItemCard({
    required this.item,
    required this.isPurchasing,
    this.onCoinPackPurchased,
  });

  final ShopItem item;
  final bool isPurchasing;

  /// Reports this card's global-coords centre after a successful coin-pack
  /// purchase, so the Shop can fly coins from here to the balance bar.
  final void Function(Offset from)? onCoinPackPurchased;

  String get _priceLabel => item.category == ShopCategory.coinPack
      ? '${item.price.toPersianStringGrouped()} تومان'
      : '${item.price.toPersianStringGrouped()} سکه';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameTheme = context.gameTheme;
    final isLocked = !item.purchasable && !item.owned;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: item.owned
            ? Border.all(color: gameTheme.successColor.withValues(alpha: 0.5))
            : null,
      ),
      child: Column(
        children: [
          Expanded(
            child: Opacity(
              opacity: isLocked ? 0.5 : 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      gameTheme.heroGradient.colors.first.withValues(
                        alpha: 0.15,
                      ),
                      gameTheme.heroGradient.colors.last.withValues(
                        alpha: 0.15,
                      ),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                alignment: Alignment.center,
                child: switch (item.category) {
                  ShopCategory.nameColor => _NameColorPreview(hex: item.hex),
                  ShopCategory.avatar => LayoutBuilder(
                    builder: (context, constraints) {
                      // Fill most of the preview box with the avatar.
                      final side = constraints.biggest.shortestSide;
                      return Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: PlayerAvatar(
                          name: item.labelFa,
                          avatarUrl: '/assets/avatar/${item.id}.png',
                          radius: (side - AppSpacing.sm * 2) / 2,
                        ),
                      );
                    },
                  ),
                  ShopCategory.coinPack => Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Image.asset(
                      AppImages.coinPackImage(item.coinAmount),
                      fit: BoxFit.contain,
                    ),
                  ),
                },
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          PText(
            item.labelFa,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (item.owned)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: gameTheme.successColor,
                ),
                const SizedBox(width: AppSpacing.xs),
                PText(
                  'خریداری‌شده',
                  style: TextStyle(color: gameTheme.successColor, fontSize: 12),
                ),
              ],
            )
          else if (isLocked)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                const SizedBox(width: AppSpacing.xs),
                PText('به‌زودی', style: Theme.of(context).textTheme.bodySmall),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                label: _priceLabel,
                isLoading: isPurchasing,
                onTap: () => item.category == ShopCategory.coinPack
                    ? _buyCoinPack(context, ref)
                    : ref.read(shopControllerProvider.notifier).purchase(item),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _buyCoinPack(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(shopControllerProvider.notifier)
        .purchaseCoinPack(item);
    if (!context.mounted) return;
    switch (result.outcome) {
      case CoinPurchaseOutcome.success:
        // Fly coins from this card to the balance bar, then confirm.
        final box = context.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          onCoinPackPurchased?.call(
            box.localToGlobal(box.size.center(Offset.zero)),
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: PText('سکه‌ها با موفقیت به حساب شما اضافه شد.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case CoinPurchaseOutcome.cancelled:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: PText('پرداخت انجام نشد یا توسط شما لغو شد.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case CoinPurchaseOutcome.unavailable:
        final storeName = StoreConfig.isMyket ? 'مایکت' : 'کافه‌بازار';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: PText('درون‌پرداخت $storeName در این دستگاه در دسترس نیست.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case CoinPurchaseOutcome.failed:
        final msg = result.errorMessage ??
            'پرداخت ناموفق بود. اگر مبلغی کسر شده، به زودی به حساب شما بازگردانده می‌شود.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: PText(msg),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFD32F2F),
          ),
        );
    }
  }
}

/// Live preview of a name-color in the Shop: a big filled swatch with a
/// sample name ("اسم من") rendered in that exact color, so the buyer sees
/// what their name will look like before paying.
class _NameColorPreview extends StatelessWidget {
  const _NameColorPreview({required this.hex});

  final String? hex;

  @override
  Widget build(BuildContext context) {
    final rainbow = isRainbowNameColor(hex);
    final glitch = isGlitchNameColor(hex);
    final color =
        parseNameColor(hex) ??
        Theme.of(context).textTheme.bodyLarge?.color ??
        Colors.white;

    final swatchDecoration = rainbow
        ? const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                Color(0xFFFF3B30),
                Color(0xFFFF9500),
                Color(0xFFFFCC00),
                Color(0xFF34C759),
                Color(0xFF32ADE6),
                Color(0xFF5856D6),
                Color(0xFFAF52DE),
                Color(0xFFFF3B30),
              ],
            ),
          )
        : glitch
        ? const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFFFF0040), Color(0xFF000000), Color(0xFF00E5FF)],
            ),
          )
        : BoxDecoration(shape: BoxShape.circle, color: color);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: swatchDecoration.copyWith(
            border: Border.all(color: Colors.white24, width: 2),
            boxShadow: [
              BoxShadow(
                color: (rainbow || glitch ? const Color(0xFF32ADE6) : color).withValues(alpha: 0.5),
                blurRadius: 12,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // ColoredName runs the rainbow / glitch animation itself.
        ColoredName(
          'اسم من',
          colorHex: hex,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends ConsumerWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PText(
              'ارتباط با سرور برقرار نشد.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: () {
                ref.read(soundServiceProvider).playButtonClick();
                onRetry();
              },
              child: const PText('تلاش دوباره'),
            ),
          ],
        ),
      ),
    );
  }
}
