import 'client_config.dart';

/// The player's level standing, as computed and returned by the server
/// (`GET /auth/me` → `levelProgress`). Level is a pure function of
/// cumulative `totalScore` — there is no `level` column server-side — but
/// the client takes these numbers straight from the server rather than
/// recomputing, so the curve can change server-side without a client
/// release. [LevelingConfig] (from `GET /config/client`) is only used to
/// draw the whole curve / as a fallback when this block is absent.
class LevelProgress {
  const LevelProgress({
    required this.pointsIntoLevel,
    required this.pointsForNextLevel,
    required this.currentLevelScore,
    required this.nextLevelScore,
    required this.progress,
    required this.isMaxLevel,
  });

  /// Score earned into the current level so far.
  final int pointsIntoLevel;

  /// Total span of the current level (currentLevelScore → nextLevelScore).
  final int pointsForNextLevel;

  /// Cumulative score at which the current level started.
  final int currentLevelScore;

  /// Cumulative score needed to reach the next level. Equal to
  /// [currentLevelScore] at max level.
  final int nextLevelScore;

  /// 0..1 toward the next level. Pinned at 1 at max level.
  final double progress;

  final bool isMaxLevel;

  factory LevelProgress.fromJson(Map<String, dynamic> json) {
    // Defensive: clamp progress to [0,1] and coerce the rest to
    // non-negative ints — this is server-shaped data but still untrusted.
    final raw = (json['progress'] as num?)?.toDouble() ?? 0;
    final progress = raw.isNaN || raw.isInfinite ? 0.0 : raw.clamp(0.0, 1.0);
    int nn(Object? v) {
      final n = (v as num?)?.toInt() ?? 0;
      return n < 0 ? 0 : n;
    }

    return LevelProgress(
      pointsIntoLevel: nn(json['pointsIntoLevel']),
      pointsForNextLevel: nn(json['pointsForNextLevel']),
      currentLevelScore: nn(json['currentLevelScore']),
      nextLevelScore: nn(json['nextLevelScore']),
      progress: progress,
      isMaxLevel: json['isMaxLevel'] as bool? ?? false,
    );
  }
}

class AuthPlayer {
  const AuthPlayer({
    required this.id,
    required this.nickname,
    required this.coinBalance,
    this.avatarUrl,
    this.nameColorHex,
    this.nicknameChangesRemaining = 0,
    this.nicknameChangeCost = 0,
    this.totalScore = 0,
    this.gamesPlayed = 0,
    this.level = 1,
    this.levelProgress,
  });

  final String id;
  final String? nickname;
  final int coinBalance;

  /// Relative path from the server (e.g. `/assets/avatar/defultavatar.png`
  /// or `/assets/avatar/avatar_ninja.png` once a custom avatar is equipped)
  /// — prepend SERVER_URL to load it.
  final String? avatarUrl;

  /// CSS hex the player's own name renders in (their equipped name-color),
  /// or null for the theme default. Comes straight from the server so the
  /// client needs no shop-catalog lookup.
  final String? nameColorHex;

  /// How many more times this player may change their nickname. The first
  /// set (during signup) is free; after that a change costs
  /// [nicknameChangeCost] coins, and once this hits 0 the field is locked.
  final int nicknameChangesRemaining;

  /// Coin cost of a nickname change while [nicknameChangesRemaining] > 0
  /// and the player already has a name.
  final int nicknameChangeCost;

  /// Lifetime cumulative score. Drives [level] / [levelProgress].
  final int totalScore;

  /// Lifetime number of games played.
  final int gamesPlayed;

  /// Current level (server-computed from [totalScore]). Defaults to 1 for a
  /// server that doesn't send it yet.
  final int level;

  /// Progress within [level]. Null when the server didn't send the block —
  /// callers fall back to [LevelingConfig] or hide the bar.
  final LevelProgress? levelProgress;

  factory AuthPlayer.fromJson(Map<String, dynamic> json) {
    int nn(Object? v) {
      if (v is num) return v < 0 ? 0 : v.toInt();
      if (v is String) {
        final parsed = int.tryParse(v);
        if (parsed != null) return parsed < 0 ? 0 : parsed;
      }
      return 0;
    }

    int? parseNum(Object? v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt();
      return null;
    }

    return AuthPlayer(
      id: json['id'] as String,
      nickname: json['nickname'] as String?,
      coinBalance: parseNum(json['coinBalance'] ?? json['coin_balance']) ?? 0,
      avatarUrl: (json['avatarUrl'] ?? json['avatar_url']) as String?,
      nameColorHex: (json['nameColorHex'] ?? json['name_color_hex']) as String?,
      nicknameChangesRemaining: parseNum(json['nicknameChangesRemaining'] ?? json['nickname_changes_remaining']) ?? 0,
      nicknameChangeCost: parseNum(json['nicknameChangeCost'] ?? json['nickname_change_cost']) ?? 0,
      totalScore: nn(json['totalScore'] ?? json['total_score'] ?? json['score']),
      gamesPlayed: nn(json['gamesPlayed'] ?? json['games_played']),
      level: () {
        final explicit = parseNum(json['level']) ??
            parseNum(json['player_level']) ??
            parseNum(json['currentLevel']) ??
            (json['levelProgress'] is Map ? parseNum(json['levelProgress']['level']) : null);
        if (explicit != null && explicit >= 1) return explicit;

        final score = nn(json['totalScore'] ?? json['total_score'] ?? json['score']);
        if (score > 0) {
          return LevelingConfig.fallback.levelForScore(score);
        }
        return 1;
      }(),
      levelProgress: json['levelProgress'] is Map
          ? LevelProgress.fromJson((json['levelProgress'] as Map).cast<String, dynamic>())
          : null,
    );
  }

  AuthPlayer copyWith({
    String? nickname,
    int? coinBalance,
    String? avatarUrl,
    String? nameColorHex,
    int? nicknameChangesRemaining,
    int? nicknameChangeCost,
    int? totalScore,
    int? gamesPlayed,
    int? level,
    LevelProgress? levelProgress,
    bool clearNameColor = false,
  }) {
    return AuthPlayer(
      id: id,
      nickname: nickname ?? this.nickname,
      coinBalance: coinBalance ?? this.coinBalance,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      nameColorHex: clearNameColor ? null : (nameColorHex ?? this.nameColorHex),
      nicknameChangesRemaining: nicknameChangesRemaining ?? this.nicknameChangesRemaining,
      nicknameChangeCost: nicknameChangeCost ?? this.nicknameChangeCost,
      totalScore: totalScore ?? this.totalScore,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      level: level ?? this.level,
      levelProgress: levelProgress ?? this.levelProgress,
    );
  }
}

class AuthSession {
  const AuthSession({required this.token, required this.isNewUser, required this.player});

  final String token;
  final bool isNewUser;
  final AuthPlayer player;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: json['token'] as String,
      isNewUser: json['isNewUser'] as bool? ?? false,
      player: AuthPlayer.fromJson((json['player'] as Map).cast<String, dynamic>()),
    );
  }
}

/// Thrown for any known backend auth error (invalid phone, wrong OTP,
/// rate-limited, etc). `code` matches the server's error codes so the UI
/// can show a tailored Farsi message.
class AuthException implements Exception {
  const AuthException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'AuthException($code): $message';
}
