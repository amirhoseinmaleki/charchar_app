enum GameMode { solo, online, multiplayer }

extension GameModeApi on GameMode {
  static GameMode fromApi(String value) => switch (value) {
        'solo' => GameMode.solo,
        'online' => GameMode.online,
        'multiplayer' => GameMode.multiplayer,
        _ => GameMode.multiplayer,
      };

  String get labelFa => switch (this) {
        GameMode.solo => 'بازی سریع',
        GameMode.online => 'بازی آنلاین',
        GameMode.multiplayer => 'بازی با دوستان',
      };
}

/// One row per game the player was part of, logged the moment it starts
/// (see server's game_history table) — [finishedAt]/[score]/[rank] stay
/// null if the game was abandoned before it ended.
class GameHistoryEntry {
  const GameHistoryEntry({
    required this.roomCode,
    required this.mode,
    required this.startedAt,
    required this.finishedAt,
    required this.score,
    required this.rank,
    required this.coinsEarned,
  });

  final String roomCode;
  final GameMode mode;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int? score;
  final int? rank;

  /// Coin prize earned from this game (بازی آنلاین top-3 prizes only —
  /// zero/null for modes with no coin payout, e.g. بازی سریع or a
  /// multiplayer room finish).
  final int? coinsEarned;

  bool get isFinished => finishedAt != null;

  factory GameHistoryEntry.fromJson(Map<String, dynamic> json) {
    final finishedAtMs = json['finishedAt'] as num?;
    return GameHistoryEntry(
      roomCode: json['roomCode'] as String,
      mode: GameModeApi.fromApi(json['mode'] as String),
      startedAt: DateTime.fromMillisecondsSinceEpoch((json['startedAt'] as num).toInt()),
      finishedAt: finishedAtMs != null ? DateTime.fromMillisecondsSinceEpoch(finishedAtMs.toInt()) : null,
      score: (json['score'] as num?)?.toInt(),
      rank: (json['rank'] as num?)?.toInt(),
      coinsEarned: (json['coinsEarned'] as num?)?.toInt(),
    );
  }
}
