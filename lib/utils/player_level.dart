import '../models/client_config.dart';

/// Client-side player level derived from a lifetime score, using the
/// server's curve (`GET /config/client` → `leveling`, mirrored in
/// [LevelingConfig]):
///
///   score to reach level L = basePoints * (L - 1) * L / 2   (quadratic)
///   level for a score       = floor((1 + sqrt(1 + 8*score/basePoints)) / 2)
///                             clamped to [1, maxLevel]
///
/// Prefer the numbers the server already computed — `AuthPlayer.level` /
/// `AuthPlayer.levelProgress` from `GET /auth/me`. Use this only where the
/// server value isn't available (e.g. a leaderboard row that only carries a
/// score), passing the live [LevelingConfig] from `remoteConfigValueProvider`.
class PlayerLevel {
  const PlayerLevel({
    required this.level,
    required this.currentLevelFloor,
    required this.nextLevelAt,
    required this.score,
    required this.isMaxLevel,
  });

  final int level;

  /// Score at which the current level started.
  final int currentLevelFloor;

  /// Score needed to reach the next level (== [currentLevelFloor] at max).
  final int nextLevelAt;

  /// The player's lifetime score this was computed from.
  final int score;

  final bool isMaxLevel;

  /// 0..1 progress through the current level. Pinned at 1 at max level.
  double get progress {
    if (isMaxLevel) return 1;
    final span = nextLevelAt - currentLevelFloor;
    if (span <= 0) return 0;
    return ((score - currentLevelFloor) / span).clamp(0.0, 1.0);
  }

  /// Compute the level standing for [score] under [leveling] (defaults to
  /// the compiled fallback curve when no config is passed).
  factory PlayerLevel.fromScore(
    int score, {
    LevelingConfig leveling = LevelingConfig.fallback,
  }) {
    final s = score < 0 ? 0 : score;
    final level = leveling.levelForScore(s);
    final isMax = level >= leveling.maxLevel;
    return PlayerLevel(
      level: level,
      currentLevelFloor: leveling.thresholdForLevel(level),
      nextLevelAt: isMax
          ? leveling.thresholdForLevel(level)
          : leveling.thresholdForLevel(level + 1),
      score: s,
      isMaxLevel: isMax,
    );
  }
}
