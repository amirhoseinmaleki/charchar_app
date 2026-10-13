import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/leaderboard.dart';
import '../services/leaderboard_service.dart';
import 'auth_provider.dart';

final leaderboardServiceProvider = Provider<LeaderboardService>((ref) => LeaderboardService());

/// Fetches the leaderboard for a given scope, re-fetching whenever the
/// scope tab changes. Family provider keyed by scope so switching tabs
/// doesn't lose the other tabs' already-loaded data if the user flips back.
final leaderboardProvider = FutureProvider.family<LeaderboardResult, LeaderboardScope>((ref, scope) async {
  final service = ref.watch(leaderboardServiceProvider);
  // Token only — a coin/cosmetic/nickname change in auth state must not
  // re-fetch (and flicker) the leaderboard.
  final token = ref.watch(authControllerProvider.select((s) => s.token));
  return service.fetch(scope: scope, token: token);
});
