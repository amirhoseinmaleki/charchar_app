import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/analytics_service.dart';
import 'auth_provider.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) => AnalyticsService());

/// Keeps the Firebase Analytics user id in sync with the logged-in player,
/// so events are attributed per user (and cleared on logout). Watch this
/// once, high in the tree (see main.dart), to arm it.
final analyticsUserSyncProvider = Provider<void>((ref) {
  final analytics = ref.watch(analyticsServiceProvider);
  final playerId = ref.watch(
    authControllerProvider.select((s) => s.player?.id),
  );
  analytics.setUser(playerId);
});
