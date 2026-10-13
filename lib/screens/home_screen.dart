import 'dart:async';

import 'package:animated_button/animated_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../widgets/tapsell_banner_ad.dart';
import '../config/coin_costs.dart';
import '../models/room.dart';
import '../models/room_events.dart';
import '../models/leaderboard.dart';
import '../providers/ad_reward_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/leaderboard_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/remote_config_provider.dart';
import '../providers/room_provider.dart';
import '../providers/socket_provider.dart';
import '../theme/app_images.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../providers/sound_provider.dart';
import '../widgets/coin_burst.dart';
import '../widgets/coin_pill.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/connection_status_bar.dart';
import '../widgets/error_dialog.dart';
import '../widgets/floating_letters_background.dart';
import '../widgets/insufficient_coins_dialog.dart';
import '../widgets/player_identity_header.dart';
import '../widgets/round_count_picker_sheet.dart';
import '../utils/persian_numbers.dart';
import '../widgets/p_text.dart';

/// Home screen: verifies theme tokens and RTL layout against a live
/// authenticated SocketService connection to the backend (connection
/// itself is kept alive app-wide by socketAutoConnectProvider — see
/// main.dart). Full settings gear / help sheet / leaderboard entry point
/// land in a later phase.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isStartingOnline = false;
  final _coinDestinationKey = GlobalKey();
  final _giftBoxKey = GlobalKey();

  // Drives the one-time entrance stagger for the whole Home column. Runs
  // once on mount; rebuilds from provider changes don't restart it.
  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  /// Wraps [child] in a fade + slide-up keyed to its position in the column,
  /// so items cascade in. [index] spreads the start times across the
  /// controller's timeline.
  Widget _staggered(int index, int total, Widget child) {
    final start = (index / (total + 4)).clamp(0.0, 0.85);
    final curve = CurvedAnimation(
      parent: _entranceController,
      curve: Interval(
        start,
        (start + 0.5).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.16),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }

  bool _isBottomSheetOpen = false;

  Future<void> _startOnlineGame() async {
    if (_isStartingOnline) return;

    setState(() => _isBottomSheetOpen = true);
    final roundsPerGame = await showRoundCountPickerSheet(
      context,
      coinCost: ref.read(onlineGameCostProvider),
    );
    if (mounted) {
      setState(() => _isBottomSheetOpen = false);
    }
    if (roundsPerGame == null || !mounted) return;

    setState(() => _isStartingOnline = true);
    try {
      final code = await ref
          .read(roomControllerProvider.notifier)
          .createOnlineGame(roundsPerGame: roundsPerGame);
      if (!mounted) return;
      context.push('/lobby', extra: code);
    } on RoomException catch (e) {
      if (!mounted) return;
      if (e.code == 'INSUFFICIENT_COINS') {
        await _offerAdForCoins(e.message);
      } else {
        ErrorDialog.show(context, e.message);
      }
    } finally {
      if (mounted) setState(() => _isStartingOnline = false);
    }
  }

  /// Shown when بازی آنلاین is rejected for INSUFFICIENT_COINS: offers the
  /// rewarded-ad flow. On a successful grant, fire the same coin-collection
  /// burst the Home gift box uses (gift box → coin pill).
  Future<void> _offerAdForCoins(String message) async {
    final granted = await InsufficientCoinsDialog.show(context, message);
    if (granted != true || !mounted) return;

    final sourceBox =
        _giftBoxKey.currentContext?.findRenderObject() as RenderBox?;
    final destBox =
        _coinDestinationKey.currentContext?.findRenderObject() as RenderBox?;
    if (sourceBox == null || destBox == null) return;

    CoinBurst.fire(
      context: context,
      from: sourceBox.localToGlobal(sourceBox.size.center(Offset.zero)),
      to: destBox.localToGlobal(destBox.size.center(Offset.zero)),
    );
    ref.read(giftBoxControllerProvider.notifier).clearJustAwarded();
  }

  /// Home is the root of the navigation stack — a bare back press here has
  /// nowhere else to pop to, so it would otherwise close the app instantly.
  /// Confirm first instead.
  Future<void> _confirmExit() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'خروج از بازی',
      message: 'آیا مطمئن هستید که می‌خواهید از بازی خارج شوید؟',
      confirmLabel: 'خروج',
    );
    if (confirmed == true) {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;
    final statusAsync = ref.watch(connectionStatusProvider);
    final auth = ref.watch(authControllerProvider);

    final isOnline = statusAsync.valueOrNull?.name == 'connected';

    // Prefer the server-computed level (GET /auth/me). Fall back to
    // deriving it from lifetime score against the live leveling curve while
    // the server value is unavailable (older server, or /auth/me not yet
    // resolved).
    final leveling = ref.watch(
      remoteConfigValueProvider.select((c) => c.config.leveling),
    );
    final lifetimeScore =
        (auth.player?.totalScore != null && auth.player!.totalScore > 0)
        ? auth.player!.totalScore
        : ref
              .watch(leaderboardProvider(LeaderboardScope.allTime))
              .valueOrNull
              ?.myRank
              ?.score;
    final serverLevel = auth.player?.level;
    final playerLevel = (serverLevel != null && serverLevel > 1)
        ? serverLevel
        : (lifetimeScore != null && lifetimeScore > 0
              ? leveling.levelForScore(lifetimeScore)
              : (serverLevel ?? 1));

    final unreadNotifications =
        ref.watch(notificationUnreadCountProvider).valueOrNull ?? 0;
    final unreadChat = ref.watch(chatUnreadCountProvider);

    // The host who backed out of their lobby (see LobbyScreen.PopScope) —
    // their room is still alive. Show a banner back into it.
    final roomState = ref.watch(roomControllerProvider);
    final hostedRoom = roomState.room;
    final isHostingOpenLobby =
        hostedRoom != null &&
        roomState.myPlayerId != null &&
        hostedRoom.hostId == roomState.myPlayerId &&
        hostedRoom.status == RoomStatus.lobby;

    // Every child fades + slides up in sequence when Home first appears, so
    // the screen assembles itself rather than snapping in all at once.
    final items = <Widget>[
      if (isHostingOpenLobby) ...[
        _HostedLobbyBanner(code: hostedRoom.code),
        const SizedBox(height: AppSpacing.md),
      ],
      Row(
        children: [
          KeyedSubtree(
            key: _coinDestinationKey,
            child: CoinPill(
              balance: auth.player?.coinBalance,
              animated: true,
              compact: true,
              onTap: () {
                ref.read(soundServiceProvider).playButtonClick();
                context.push('/shop');
              },
            ),
          ),
          const Spacer(),
          KeyedSubtree(
            key: _giftBoxKey,
            child: _GiftBoxButton(destinationKey: _coinDestinationKey),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      GestureDetector(
        onTap: () {
          ref.read(soundServiceProvider).playButtonClick();
          context.push('/profile');
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            PlayerIdentityHeader(
              nickname: auth.player?.nickname,
              avatarUrl: auth.player?.avatarUrl,
              nameColorHex: auth.player?.nameColorHex,
              level: playerLevel,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CircleIconButton(
                  iconImage: AppImages.notification,
                  badgeCount: unreadNotifications,
                  onTap: () => context
                      .push('/notifications')
                      .then(
                        (_) => ref.invalidate(notificationUnreadCountProvider),
                      ),
                ),
                const SizedBox(width: AppSpacing.md),
                _CircleIconButton(
                  iconImage: AppImages.chat,
                  badgeCount: unreadChat,
                  onTap: () => context.push('/chat'),
                ),
                const SizedBox(width: AppSpacing.md),
                _CircleIconButton(
                  iconImage: AppImages.setting,
                  onTap: () => context.push('/settings'),
                ),
              ],
            ),
          ],
        ),
      ),
      // Only surface the status chip when something is wrong — when
      // connected it's just noise (the ConnectionStatusBar up top already
      // covers the disconnected/reconnecting states too). Kept in the list
      // unconditionally (collapsed when online) so the item count — and thus
      // the entrance-stagger indices — stay stable across rebuilds.
      if (!isOnline)
        const SizedBox(height: AppSpacing.md)
      else
        const SizedBox.shrink(),
      isOnline ? const SizedBox.shrink() : _StatusChip(isOnline: isOnline),
      const SizedBox(height: AppSpacing.xl),
      _HeroButton(
        icon: LucideIcons.zap,
        iconImage: AppImages.play,
        label: 'بازی آنلاین',
        subtitle: 'ورود سریع به یک بازی',
        gradient: gameTheme.heroGradient,
        isLoading: _isStartingOnline,
        onTap: _startOnlineGame,
      ),
      const SizedBox(height: AppSpacing.lg),
      _HeroButton(
        icon: LucideIcons.users,
        iconImage: AppImages.team,
        label: 'بازی با دوستان',
        subtitle: 'ساخت یا ورود به اتاق',
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.secondary,
            Theme.of(context).colorScheme.primary,
          ],
        ),
        onTap: () => context.push('/create-join'),
      ),
      const SizedBox(height: AppSpacing.lg),
      _HeroButton(
        icon: LucideIcons.store,
        iconImage: AppImages.shoppingCart,
        label: 'فروشگاه',
        subtitle: 'آواتار، رنگ اسم و قاب',
        gradient: gameTheme.baseGradient,
        onTap: () => context.push('/shop'),
      ),
      const SizedBox(height: AppSpacing.lg),
      _HeroButton(
        icon: LucideIcons.trophy,
        iconImage: AppImages.rank,
        label: 'برترین بازیکنان',
        subtitle: 'رتبه‌بندی و امتیازها',
        gradient: const LinearGradient(
          colors: [Color(0xFFF5C542), Color(0xFFE07A2E)],
        ),
        onTap: () => context.push('/leaderboard'),
      ),
      // The Profile + Settings row is hidden — both are reachable from the
      // circular icons under the avatar. (_CompactHeroButton kept for now
      // in case the row comes back.)
      const SizedBox(height: AppSpacing.md),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmExit();
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Decorative drifting Persian letters — a nod to the word game.
            Positioned.fill(
              child: FloatingLettersBackground(
                color: gameTheme.heroGradient.colors.first,
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const ConnectionStatusBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      // No top padding — the coin pill / gift-box row sits
                      // flush against the connection bar.
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenPadding,
                        0,
                        AppSpacing.screenPadding,
                        AppSpacing.screenPadding + 60,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < items.length; i++)
                            _staggered(i, items.length, items[i]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: TapsellBannerAd(visible: !_isBottomSheetOpen),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The gift-box button: tap → show a Tapsell rewarded video → on success,
/// fire coins flying from this button to the coin pill (via [CoinBurst])
/// and refresh the real balance. While the reward is on cooldown it shows
/// a live HH:MM:SS countdown under the (dimmed) box instead.
class _GiftBoxButton extends ConsumerStatefulWidget {
  const _GiftBoxButton({required this.destinationKey});

  final GlobalKey destinationKey;

  @override
  ConsumerState<_GiftBoxButton> createState() => _GiftBoxButtonState();
}

class _GiftBoxButtonState extends ConsumerState<_GiftBoxButton> {
  final _sourceKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decode the coin image ahead of time so the fly-to-balance animation
    // doesn't spend its first frames waiting on an image load.
    precacheImage(const AssetImage(AppImages.coin), context);
  }

  Future<void> _handleTap() async {
    final flow = ref.read(giftBoxControllerProvider).flow;
    if (flow != GiftBoxFlowState.idle) return;

    ref.read(soundServiceProvider).playButtonClick();
    final errorMessage = await ref
        .read(giftBoxControllerProvider.notifier)
        .watchAd();
    if (kDebugMode) {
      debugPrint(
        '[GiftBox] _handleTap: errorMessage=$errorMessage mounted=$mounted',
      );
    }
    if (!mounted) return;

    if (errorMessage != null) {
      ErrorDialog.show(context, errorMessage, title: 'جایزه دریافت نشد');
      return;
    }

    _fireCoinAnimation();
  }

  void _fireCoinAnimation() {
    final sourceBox =
        _sourceKey.currentContext?.findRenderObject() as RenderBox?;
    final destBox =
        widget.destinationKey.currentContext?.findRenderObject() as RenderBox?;
    if (sourceBox == null || destBox == null) {
      ref.read(giftBoxControllerProvider.notifier).clearJustAwarded();
      return;
    }

    final start = sourceBox.localToGlobal(sourceBox.size.center(Offset.zero));
    final end = destBox.localToGlobal(destBox.size.center(Offset.zero));
    if (kDebugMode) debugPrint('[GiftBox] coin burst start=$start end=$end');

    CoinBurst.fire(context: context, from: start, to: end);
    ref.read(giftBoxControllerProvider.notifier).clearJustAwarded();
  }

  @override
  Widget build(BuildContext context) {
    final giftBoxState = ref.watch(giftBoxControllerProvider);
    final isBusy = giftBoxState.flow != GiftBoxFlowState.idle;
    final canWatch = giftBoxState.status?.canWatch ?? true;
    final cooldownEndsAt = giftBoxState.status?.cooldownEndsAt;

    final icon = isBusy
        ? const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Opacity(
            opacity: canWatch ? 1 : 0.4,
            child: Image.asset(AppImages.giftBox, width: 52, height: 52),
          );

    // A gentle looping wiggle + pulse to draw the eye — only while a reward
    // is actually available to claim (not mid-flow, not on cooldown).
    final animatedIcon = (!isBusy && canWatch)
        ? icon
              .animate(onPlay: (c) => c.repeat())
              // one attention beat, then a long pause before it repeats
              .then(delay: 2600.ms)
              .shake(hz: 4, duration: 600.ms, rotation: 0.06)
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.14, 1.14),
                duration: 300.ms,
                curve: Curves.easeOut,
              )
              .then()
              .scale(
                begin: const Offset(1.14, 1.14),
                end: const Offset(1, 1),
                duration: 300.ms,
                curve: Curves.easeIn,
              )
        : icon;

    final showCountdown =
        !isBusy &&
        !canWatch &&
        cooldownEndsAt != null &&
        cooldownEndsAt.isAfter(DateTime.now());

    // The button is a FIXED 68x68 box and nothing else — its size never
    // changes, so the Row it sits in (and the coin pill next to it) never
    // reflows. The countdown is a Positioned overlay hanging BELOW the box
    // via an overflowing Stack: it takes zero layout space, so it appearing
    // / disappearing / ticking can't move anything.
    return SizedBox(
      key: _sourceKey,
      width: 68,
      height: 68,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          IconButton(
            tooltip: canWatch ? 'دریافت سکه رایگان' : 'تا جایزهٔ بعدی صبر کنید',
            onPressed: (isBusy || !canWatch) ? null : _handleTap,
            icon: animatedIcon,
          ),
          if (showCountdown)
            Positioned(
              // Fixed geometry: a 92-wide box centred under the 68-wide
              // button (68-92)/2 = -12. left+width pin it exactly so the
              // label can never drift as its text width changes.
              left: -12,
              top: 62,
              width: 92,
              child: _CooldownLabel(
                endsAt: cooldownEndsAt,
                onElapsed: () => ref
                    .read(giftBoxControllerProvider.notifier)
                    .refreshStatus(),
              ),
            )
          else
            const Positioned(
              left: -12,
              top: 62,
              width: 92,
              child: Text(
                'سکه رایگان',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Self-contained HH:MM:SS countdown. Owns its 1s repaint timer so the
/// gift-box button it sits under never rebuilds on a tick.
class _CooldownLabel extends StatefulWidget {
  const _CooldownLabel({required this.endsAt, required this.onElapsed});

  final DateTime endsAt;
  final VoidCallback onElapsed;

  @override
  State<_CooldownLabel> createState() => _CooldownLabelState();
}

class _CooldownLabelState extends State<_CooldownLabel> {
  late Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!widget.endsAt.isAfter(DateTime.now())) {
        _ticker.cancel();
        widget.onElapsed();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    // Always HH:MM:SS, zero-padded, so the width is constant tick to tick.
    final hh = d.inHours.toString().padLeft(2, '0');
    final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.endsAt.difference(DateTime.now());
    // The parent Positioned fixes this widget's width (92) and left edge,
    // so the capsule is a constant size and can't drift. Content is
    // centred inside it; the digits use Latin numerals (not PText's
    // Persian conversion) + monospace so every tick is the exact same
    // width.
    return Container(
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.clock, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            _fmt(remaining.isNegative ? Duration.zero : remaining),
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              fontFamily: 'monospace',
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown on Home when the player is still hosting an open lobby they backed
/// out of — tap to jump back in.
class _HostedLobbyBanner extends ConsumerWidget {
  const _HostedLobbyBanner({required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameTheme = context.gameTheme;
    return GestureDetector(
      onTap: () {
        ref.read(soundServiceProvider).playButtonClick();
        context.push('/lobby', extra: code);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          gradient: gameTheme.heroGradient,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.users, color: Colors.white, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: PText(
                'اتاق $code باز است — بازگشت به لابی',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(LucideIcons.chevronLeft, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}

/// A round icon button under the Home avatar (notifications / settings).
/// Taps play the shared click sound and a quick shrink-and-return scale
/// bounce before running [onTap]. [badgeCount] > 0 draws a count bubble on
/// the upper-right.
class _CircleIconButton extends ConsumerStatefulWidget {
  const _CircleIconButton({
    required this.iconImage,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String iconImage;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  ConsumerState<_CircleIconButton> createState() => _CircleIconButtonState();
}

class _CircleIconButtonState extends ConsumerState<_CircleIconButton>
    with SingleTickerProviderStateMixin {
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
    final accent = context.gameTheme.heroGradient.colors.first;
    final count = widget.badgeCount;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scale,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Same treatment as the nickname nameplate.
                color: Theme.of(context).cardTheme.color,
                border: Border.all(color: accent.withValues(alpha: 0.35)),
              ),
              alignment: Alignment.center,
              child: Image.asset(widget.iconImage, width: 22, height: 22),
            ),
            if (count > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: context.gameTheme.invalidColor,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: PText(
                    count > 99 ? '۹۹+' : count.toPersianString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;
    final color = isOnline ? gameTheme.successColor : gameTheme.invalidColor;
    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.xs),
            PText(
              isOnline ? 'متصل به سرور' : 'در حال اتصال...',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroButton extends ConsumerWidget {
  const _HeroButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
    this.iconImage,
    this.isLoading = false,
  });

  final IconData icon;

  /// Optional asset path shown in place of [icon] (e.g. the "بازی آنلاین"
  /// play graphic). When null, [icon] is rendered as before.
  final String? iconImage;
  final String label;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;
  final bool isLoading;

  static const _height = 84.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.hasBoundedWidth && constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 320.0;

        return AnimatedButton(
          width: width,
          height: _height,
          borderRadius: AppRadius.lg,
          color: gradient.colors.first,
          enabled: !isLoading,
          onPressed: () {
            ref.read(soundServiceProvider).playButtonClick();
            onTap();
          },
          child: Container(
            width: width,
            height: _height,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else if (iconImage != null)
                  Image.asset(iconImage!, width: 68, height: 68)
                else
                  Icon(icon, color: Colors.white, size: 32),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PText(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      PText(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
