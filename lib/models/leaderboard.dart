class LeaderboardEntry {
  const LeaderboardEntry({
    required this.playerId,
    required this.nickname,
    required this.score,
    required this.rank,
    this.nameColorHex,
    this.avatarUrl,
  });

  final String playerId;
  final String nickname;
  final int score;
  final int rank;

  /// Server-resolved hex for this player's equipped name-color (null =
  /// default). Use with [ColoredName].
  final String? nameColorHex;

  /// Server-relative path for this player's equipped avatar image.
  final String? avatarUrl;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      playerId: json['playerId'] as String,
      nickname: json['nickname'] as String,
      score: (json['score'] as num).toInt(),
      rank: (json['rank'] as num).toInt(),
      nameColorHex: json['nameColorHex'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

enum LeaderboardScope { allTime, weekly, monthly }

extension LeaderboardScopeApi on LeaderboardScope {
  String get apiValue => switch (this) {
        LeaderboardScope.allTime => 'allTime',
        LeaderboardScope.weekly => 'weekly',
        LeaderboardScope.monthly => 'monthly',
      };

  String get labelFa => switch (this) {
        LeaderboardScope.allTime => 'همه زمان‌ها',
        LeaderboardScope.weekly => 'این هفته',
        LeaderboardScope.monthly => 'این ماه',
      };
}

class MyRank {
  const MyRank({required this.score, required this.rank});

  final int score;
  final int rank;

  factory MyRank.fromJson(Map<String, dynamic> json) {
    return MyRank(score: (json['score'] as num).toInt(), rank: (json['rank'] as num).toInt());
  }
}

class LeaderboardResult {
  const LeaderboardResult({required this.entries, required this.myRank, this.size = 100});

  final List<LeaderboardEntry> entries;
  final MyRank? myRank;

  /// Fixed board length reported by the server (always 100). The count of
  /// rows the top list is capped at.
  final int size;

  /// The row in [entries] that belongs to the signed-in caller, matched by
  /// `rank` alone — ranks are dense and unique (no ties), so `myRank.rank`
  /// identifies exactly one row when the caller is inside the board (per
  /// leaderboard.md). `null` when the caller has no rank, or `myRank.rank`
  /// falls past the visible list.
  LeaderboardEntry? get myEntryInList {
    final me = myRank;
    if (me == null || me.rank > entries.length) return null;
    for (final e in entries) {
      if (e.rank == me.rank) return e;
    }
    return null;
  }

  factory LeaderboardResult.fromJson(Map<String, dynamic> json) {
    return LeaderboardResult(
      entries: (json['entries'] as List).map((e) => LeaderboardEntry.fromJson((e as Map).cast())).toList(),
      myRank: json['myRank'] != null ? MyRank.fromJson((json['myRank'] as Map).cast()) : null,
      size: json['size'] != null ? (json['size'] as num).toInt() : 100,
    );
  }
}
