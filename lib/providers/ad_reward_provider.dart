import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ad_reward.dart';
import '../services/ad_reward_service.dart';
import '../services/ad_service.dart';
import '../utils/persian_numbers.dart';
import 'auth_provider.dart';
import 'push_provider.dart';
import 'remote_config_provider.dart';

final adServiceProvider = Provider<AdService>((ref) => AdService());
final adRewardServiceProvider = Provider<AdRewardService>((ref) => AdRewardService());

enum GiftBoxFlowState { idle, loadingAd, showingAd, granting }

class GiftBoxState {
  const GiftBoxState({
    this.status,
    this.flow = GiftBoxFlowState.idle,
    this.coinsJustAwarded,
    this.statusAttempted = false,
  });

  final AdRewardStatus? status;
  final GiftBoxFlowState flow;

  /// Set only for the brief window after a successful claim, to trigger the
  /// coin-collection animation exactly once per reward.
  final int? coinsJustAwarded;

  /// True once the first `refreshStatus()` has finished — whether it
  /// succeeded or failed. Splash readiness keys off this so a flaky
  /// `/ads/reward-status` doesn't hang the splash forever.
  final bool statusAttempted;

  GiftBoxState copyWith({
    AdRewardStatus? status,
    GiftBoxFlowState? flow,
    int? coinsJustAwarded,
    bool? statusAttempted,
    bool clearCoinsJustAwarded = false,
  }) {
    return GiftBoxState(
      status: status ?? this.status,
      flow: flow ?? this.flow,
      coinsJustAwarded: clearCoinsJustAwarded ? null : (coinsJustAwarded ?? this.coinsJustAwarded),
      statusAttempted: statusAttempted ?? this.statusAttempted,
    );
  }

  static const initial = GiftBoxState();
}

/// Owns the whole "watch ad for coins" flow: checking eligibility, driving
/// the Tapsell ad, and claiming the reward — so the Home screen's gift-box
/// button only ever needs to call [watchAd] and react to [GiftBoxState].
class GiftBoxController extends StateNotifier<GiftBoxState> {
  GiftBoxController(this._adService, this._rewardService, this._ref) : super(GiftBoxState.initial) {
    refreshStatus();
    // The ad-reward rate limit is per USER, enforced by the server keyed on
    // player id. When the signed-in account changes (logout → login as
    // someone else), the previous user's cooldown/quota must not linger —
    // wipe local status and re-fetch for the new token.
    _ref.listen<String?>(
      authControllerProvider.select((s) => s.token),
      (previous, next) {
        if (previous == next) return;
        _cooldownTimer?.cancel();
        _ref.read(pushServiceProvider).cancelNotification(_rewardNotificationId);
        state = GiftBoxState.initial;
        refreshStatus();
      },
    );
  }

  final AdService _adService;
  final AdRewardService _rewardService;
  final Ref _ref;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  static const _rewardNotificationId = 7771;

  /// Arms (or disarms) the "free coins ready" local notification from a
  /// fresh [status]: only when a cooldown is running AND the user still has
  /// views left today — otherwise the ad wouldn't actually be watchable when
  /// it fires.
  void _syncRewardNotification(AdRewardStatus status) {
    final endsAt = status.cooldownEndsAt;
    if (endsAt != null && endsAt.isAfter(DateTime.now()) && status.viewsRemainingToday > 0) {
      _scheduleCooldownNotification(endsAt);
    } else {
      _cooldownTimer?.cancel();
      _ref.read(pushServiceProvider).cancelNotification(_rewardNotificationId);
    }
  }

  void _scheduleCooldownNotification(DateTime cooldownEndsAt) {
    _cooldownTimer?.cancel();
    final pushService = _ref.read(pushServiceProvider);
    pushService.scheduleNotification(
      id: _rewardNotificationId,
      title: '🎁 سکه رایگان آماده شد!',
      body: 'همین حالا وارد بازی شو و با تماشای تبلیغ، سکه رایگانت رو دریافت کن!',
      scheduledDate: cooldownEndsAt,
    );

    final delay = cooldownEndsAt.difference(DateTime.now());
    if (delay.isNegative || delay == Duration.zero) return;

    _cooldownTimer = Timer(delay, () {
      // Refresh status so the gift box becomes clickable again if the user is still inside the app
      refreshStatus();
    });
  }

  Future<void> refreshStatus() async {
    final token = _ref.read(authControllerProvider).token;
    if (token == null) {
      // Signed out — clear any stale eligibility from the previous session.
      _cooldownTimer?.cancel();
      state = GiftBoxState.initial;
      return;
    }
    try {
      final status = await _rewardService.fetchStatus(token);
      state = state.copyWith(status: status, statusAttempted: true);
      _syncRewardNotification(status);
    } catch (_) {
      // Silent — the gift box just won't show a precise countdown until
      // the next successful refresh; not worth an error dialog on its own.
      state = state.copyWith(statusAttempted: true);
    }
  }

  /// Returns a Farsi message to show via ErrorDialog if the flow couldn't
  /// complete, or null on success (the coin animation + refreshed status
  /// are already applied to state by the time this returns).
  Future<String?> watchAd() async {
    if (state.flow != GiftBoxFlowState.idle) return null;

    final currentStatus = state.status;
    if (currentStatus != null && !currentStatus.canWatch) {
      return _ineligibleMessage(currentStatus);
    }

    final token = _ref.read(authControllerProvider).token;
    if (token == null) return 'نشست شما نامعتبر است. دوباره وارد شوید.';

    state = state.copyWith(flow: GiftBoxFlowState.loadingAd);
    final remoteConfig = _ref.read(remoteConfigValueProvider);
    final result = await _adService.watchRewardedAd(remoteConfig);
    if (kDebugMode) debugPrint('[GiftBox] watchRewardedAd -> $result');

    if (result != AdWatchResult.rewarded) {
      state = state.copyWith(flow: GiftBoxFlowState.idle);
      return result == AdWatchResult.closedWithoutReward
          ? 'برای دریافت جایزه باید تبلیغ را تا انتها تماشا کنید.'
          : 'در حال حاضر تبلیغی برای نمایش موجود نیست. کمی بعد دوباره امتحان کنید.';
    }

    state = state.copyWith(flow: GiftBoxFlowState.granting);
    if (kDebugMode) debugPrint('[GiftBox] claiming reward...');
    try {
      final claim = await _rewardService.claimReward(token);
      if (kDebugMode) debugPrint('[GiftBox] claim OK: +${claim.status.coinAmount}, balance=${claim.coinBalance}');
      _ref.read(authControllerProvider.notifier).updateCoinBalance(claim.coinBalance);
      state = state.copyWith(status: claim.status, flow: GiftBoxFlowState.idle, coinsJustAwarded: claim.status.coinAmount);
      _syncRewardNotification(claim.status);
      return null;
    } on AdRewardException catch (e) {
      if (kDebugMode) debugPrint('[GiftBox] claim FAILED: ${e.code} / ${e.message}');
      if (e.status != null) {
        state = state.copyWith(status: e.status);
        _syncRewardNotification(e.status!);
      }
      state = state.copyWith(flow: GiftBoxFlowState.idle);
      return e.message;
    }
  }

  void clearJustAwarded() {
    state = state.copyWith(clearCoinsJustAwarded: true);
  }

  String _ineligibleMessage(AdRewardStatus status) {
    final cooldownEndsAt = status.cooldownEndsAt;
    if (cooldownEndsAt != null) {
      final remaining = cooldownEndsAt.difference(DateTime.now());
      final hours = remaining.inHours;
      final minutes = remaining.inMinutes % 60;
      if (remaining.isNegative) return 'برای تماشای تبلیغ بعدی کمی صبر کنید.';
      final hoursPart = hours > 0 ? '${hours.toPersianString()} ساعت و ' : '';
      return 'برای تماشای تبلیغ بعدی باید $hoursPart${minutes.toPersianString()} دقیقه صبر کنید.';
    }
    return 'سقف تماشای تبلیغ امروز شما تمام شده. فردا دوباره تلاش کنید.';
  }
}

final giftBoxControllerProvider = StateNotifierProvider<GiftBoxController, GiftBoxState>((ref) {
  return GiftBoxController(ref.watch(adServiceProvider), ref.watch(adRewardServiceProvider), ref);
});
