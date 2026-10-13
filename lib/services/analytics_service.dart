import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper over Firebase Analytics so screens log events through one
/// place (and calls are cheap no-ops if analytics collection is disabled).
///
/// Firebase Analytics does NOT need Google Play Services — it uses its own
/// transport — so this works on every Android device, Bazaar market
/// included.
class AnalyticsService {
  AnalyticsService([FirebaseAnalytics? analytics])
      : analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics analytics;

  /// A [NavigatorObserver] for go_router — logs a `screen_view` on every
  /// route change. Add to `GoRouter(observers: [...])`.
  FirebaseAnalyticsObserver get routeObserver =>
      FirebaseAnalyticsObserver(analytics: analytics);

  Future<void> logEvent(String name, [Map<String, Object>? params]) async {
    try {
      await analytics.logEvent(name: name, parameters: params);
    } catch (e) {
      if (kDebugMode) debugPrint('[analytics] logEvent($name) failed: $e');
    }
  }

  /// Call once the player id is known (after login) / with null on logout.
  Future<void> setUser(String? playerId) async {
    try {
      await analytics.setUserId(id: playerId);
    } catch (e) {
      if (kDebugMode) debugPrint('[analytics] setUserId failed: $e');
    }
  }

  // A few named helpers for the events we actually care about; add more as
  // needed rather than sprinkling raw strings around the codebase.
  Future<void> gameStarted({required int players}) =>
      logEvent('game_started', {'players': players});

  Future<void> roundFinished({required int roundNumber}) =>
      logEvent('round_finished', {'round_number': roundNumber});

  Future<void> coinsPurchased({required String pack, required int coins}) =>
      logEvent('coins_purchased', {'pack': pack, 'coins': coins});

  Future<void> rewardedAdCompleted() => logEvent('rewarded_ad_completed');
}
