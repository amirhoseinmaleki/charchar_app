import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ad_reward_provider.dart';
import 'auth_provider.dart';
import 'remote_config_provider.dart';

/// Everything the splash screen waits on before the app is allowed past
/// `/splash`. All of it must be true:
///
/// - `GET /config/client` succeeded (`RemoteConfigStatus.ready`) — this is
///   the "is the backend reachable" check; a failure shows the retry state.
/// - the auth session restore has resolved (token → `GET /auth/me`), so
///   Home builds with the real player record, not placeholders.
/// - the gift-box reward status has loaded (`GET /ads/reward-status`), so
///   the Home gift box shows its real countdown immediately.
/// - the ~3s minimum splash time has elapsed, so the progress bar plays out.
///
/// The progress bar's final jump to 100% is driven off [splashReadyProvider]
/// too — if the config fetch fails, `ready` never becomes true and the bar
/// never fills.
final splashReadyProvider = Provider<bool>((ref) {
  final configReady = ref.watch(
    remoteConfigProvider.select((s) => s.status == RemoteConfigStatus.ready),
  );
  final authStatus = ref.watch(authControllerProvider.select((s) => s.status));
  final authResolved = authStatus != AuthStatus.unknown;

  // Gift-box status is only meaningful (and only fetched) for a logged-in
  // player — don't block a logged-out user's trip to /login on it. And we
  // wait for the *attempt*, not a success, so a flaky /ads/reward-status
  // can't hang the splash.
  final needGiftBox = authStatus == AuthStatus.loggedIn;
  final giftBoxLoaded = ref.watch(
    giftBoxControllerProvider.select((s) => s.statusAttempted),
  );

  final minTimeElapsed = ref.watch(splashMinTimeProvider);

  return configReady && authResolved && (!needGiftBox || giftBoxLoaded) && minTimeElapsed;
});
