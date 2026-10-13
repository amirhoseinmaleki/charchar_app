import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/client_config.dart';
import '../providers/remote_config_provider.dart';

/// Display-only coin costs, sourced from `GET /config/client` (the
/// `economy` / `onlineGame` blocks) via [remoteConfigValueProvider]. The
/// server is always the real charge authority — if what the client shows
/// ever drifts from the server, the worst case is a confirmation screen
/// with a stale number; the actual charge (and any `INSUFFICIENT_COINS`
/// rejection) always reflects the server's real cost.
///
/// Until the first successful fetch (and if it fails) these resolve to
/// [ClientConfig.fallback] — the values the app shipped with — so screens
/// never render a blank or a zero.

/// Coins to create a private room ("بازی با دوستان" → ساخت اتاق).
final createRoomCostProvider = Provider<int>((ref) {
  return ref.watch(
    remoteConfigValueProvider.select((c) => c.config.economy.createRoomCost),
  );
});

/// Coins to join an existing private room ("بازی با دوستان" → ورود به اتاق).
final joinRoomCostProvider = Provider<int>((ref) {
  return ref.watch(
    remoteConfigValueProvider.select((c) => c.config.economy.joinRoomCost),
  );
});

/// Coins to start a "بازی آنلاین" quick match.
final onlineGameCostProvider = Provider<int>((ref) {
  return ref.watch(
    remoteConfigValueProvider.select((c) => c.config.onlineGame.cost),
  );
});
