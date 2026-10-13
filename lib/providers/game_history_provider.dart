import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_history.dart';
import 'auth_provider.dart';

/// The current player's last 10 games (GET /auth/me/games), shown on the
/// Profile screen. Keyed on the session token only — an unrelated
/// auth-state change (coin balance, equipped cosmetics, nickname) must not
/// invalidate and re-fetch this list. Re-fetches on token change or an
/// explicit invalidate (pull-to-refresh).
final recentGamesProvider = FutureProvider<List<GameHistoryEntry>>((ref) async {
  final token = ref.watch(authControllerProvider.select((s) => s.token));
  if (token == null) return const [];
  return ref.read(authServiceProvider).fetchRecentGames(token);
});
