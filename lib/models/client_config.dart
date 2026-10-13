import 'dart:math' as math;

/// The server-authoritative gameplay numbers half of `GET /config/client`
/// (see the backend's `client-config.md`). Everything here is **advisory,
/// for display only** — the socket flow re-charges and re-scores on the
/// server regardless of what the client believed. Treat every field as
/// untrusted input: parse defensively, clamp to sane ranges, and fall back
/// to the compiled defaults when the server omits or garbles a value.
///
/// The SDK-key half of the response lives in [RemoteConfig].

int _asInt(Object? v, int fallback, {int? min, int? max}) {
  final n = v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
  if (n == null) return fallback;
  var out = n;
  if (min != null && out < min) out = min;
  if (max != null && out > max) out = max;
  return out;
}

Map<String, dynamic> _asMap(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};

/// Coin cost / reward of every action. Mirrors the server's `economy`
/// block; the server's `game/economy.ts` is the real authority.
class Economy {
  const Economy({
    required this.createRoomCost,
    required this.joinRoomCost,
    required this.onlineGameCost,
    required this.newPlayerStartingCoins,
    required this.nicknameChangeCost,
    required this.nicknameMaxChanges,
    required this.adRewardCoinAmount,
    required this.adRewardMaxPerDay,
    required this.adRewardCooldownSeconds,
    required this.adRescueCoinAmount,
    required this.adRescueMaxPerDay,
    required this.adRescueBalanceThreshold,
  });

  final int createRoomCost;
  final int joinRoomCost;
  final int onlineGameCost;
  final int newPlayerStartingCoins;
  final int nicknameChangeCost;
  final int nicknameMaxChanges;
  final int adRewardCoinAmount;
  final int adRewardMaxPerDay;
  final int adRewardCooldownSeconds;
  final int adRescueCoinAmount;
  final int adRescueMaxPerDay;
  final int adRescueBalanceThreshold;

  /// Compiled defaults — the values the app shipped with. Used until the
  /// first successful fetch and whenever the server omits the block.
  static const fallback = Economy(
    createRoomCost: 500,
    joinRoomCost: 100,
    onlineGameCost: 100,
    newPlayerStartingCoins: 500,
    nicknameChangeCost: 5000,
    nicknameMaxChanges: 2,
    adRewardCoinAmount: 100,
    adRewardMaxPerDay: 5,
    adRewardCooldownSeconds: 14400,
    adRescueCoinAmount: 100,
    adRescueMaxPerDay: 5,
    adRescueBalanceThreshold: 100,
  );

  factory Economy.fromJson(Map<String, dynamic> json) {
    const f = fallback;
    // All costs are coins: non-negative, and capped well above any real
    // value so a malformed huge number can't render as a scary price.
    const maxCoins = 10000000;
    return Economy(
      createRoomCost: _asInt(json['createRoomCost'], f.createRoomCost, min: 0, max: maxCoins),
      joinRoomCost: _asInt(json['joinRoomCost'], f.joinRoomCost, min: 0, max: maxCoins),
      onlineGameCost: _asInt(json['onlineGameCost'], f.onlineGameCost, min: 0, max: maxCoins),
      newPlayerStartingCoins:
          _asInt(json['newPlayerStartingCoins'], f.newPlayerStartingCoins, min: 0, max: maxCoins),
      nicknameChangeCost:
          _asInt(json['nicknameChangeCost'], f.nicknameChangeCost, min: 0, max: maxCoins),
      nicknameMaxChanges: _asInt(json['nicknameMaxChanges'], f.nicknameMaxChanges, min: 0, max: 100),
      adRewardCoinAmount:
          _asInt(json['adRewardCoinAmount'], f.adRewardCoinAmount, min: 0, max: maxCoins),
      adRewardMaxPerDay: _asInt(json['adRewardMaxPerDay'], f.adRewardMaxPerDay, min: 0, max: 1000),
      adRewardCooldownSeconds: _asInt(json['adRewardCooldownSeconds'], f.adRewardCooldownSeconds,
          min: 0, max: 86400),
      adRescueCoinAmount:
          _asInt(json['adRescueCoinAmount'], f.adRescueCoinAmount, min: 0, max: maxCoins),
      adRescueMaxPerDay: _asInt(json['adRescueMaxPerDay'], f.adRescueMaxPerDay, min: 0, max: 1000),
      adRescueBalanceThreshold: _asInt(json['adRescueBalanceThreshold'], f.adRescueBalanceThreshold,
          min: 0, max: maxCoins),
    );
  }
}

/// "بازی آنلاین" quick-match parameters.
class OnlineGameConfig {
  const OnlineGameConfig({
    required this.cost,
    required this.minPlayers,
    required this.maxPlayers,
    required this.prizeFirst,
    required this.prizeSecond,
    required this.prizeThird,
  });

  final int cost;
  final int minPlayers;
  final int maxPlayers;
  final int prizeFirst;
  final int prizeSecond;
  final int prizeThird;

  static const fallback = OnlineGameConfig(
    cost: 100,
    minPlayers: 3,
    maxPlayers: 5,
    prizeFirst: 150,
    prizeSecond: 75,
    prizeThird: 25,
  );

  factory OnlineGameConfig.fromJson(Map<String, dynamic> json) {
    const f = fallback;
    final prizes = _asMap(json['prizes']);
    final minP = _asInt(json['minPlayers'], f.minPlayers, min: 2, max: 20);
    return OnlineGameConfig(
      cost: _asInt(json['cost'], f.cost, min: 0, max: 10000000),
      minPlayers: minP,
      // maxPlayers can never be below minPlayers.
      maxPlayers: _asInt(json['maxPlayers'], f.maxPlayers, min: minP, max: 20),
      prizeFirst: _asInt(prizes['first'], f.prizeFirst, min: 0, max: 10000000),
      prizeSecond: _asInt(prizes['second'], f.prizeSecond, min: 0, max: 10000000),
      prizeThird: _asInt(prizes['third'], f.prizeThird, min: 0, max: 10000000),
    );
  }
}

/// Per-answer / per-game scoring. `pointsUnique/Shared/Invalid` are
/// compile-time constants on the server (`SCORING_POINTS`); the rank
/// bonuses are env-backed.
class ScoringConfig {
  const ScoringConfig({
    required this.pointsUnique,
    required this.pointsShared,
    required this.pointsInvalid,
    required this.rankBonusFirst,
    required this.rankBonusSecond,
    required this.rankBonusThird,
  });

  final int pointsUnique;
  final int pointsShared;
  final int pointsInvalid;
  final int rankBonusFirst;
  final int rankBonusSecond;
  final int rankBonusThird;

  static const fallback = ScoringConfig(
    pointsUnique: 10,
    pointsShared: 5,
    pointsInvalid: 0,
    rankBonusFirst: 200,
    rankBonusSecond: 100,
    rankBonusThird: 50,
  );

  factory ScoringConfig.fromJson(Map<String, dynamic> json) {
    const f = fallback;
    return ScoringConfig(
      pointsUnique: _asInt(json['pointsUnique'], f.pointsUnique, min: 0, max: 100000),
      pointsShared: _asInt(json['pointsShared'], f.pointsShared, min: 0, max: 100000),
      pointsInvalid: _asInt(json['pointsInvalid'], f.pointsInvalid, min: 0, max: 100000),
      rankBonusFirst: _asInt(json['rankBonusFirst'], f.rankBonusFirst, min: 0, max: 100000),
      rankBonusSecond: _asInt(json['rankBonusSecond'], f.rankBonusSecond, min: 0, max: 100000),
      rankBonusThird: _asInt(json['rankBonusThird'], f.rankBonusThird, min: 0, max: 100000),
    );
  }
}

/// Round / game timing, in seconds.
class TimingConfig {
  const TimingConfig({
    required this.roundDurationSeconds,
    required this.roundsPerGame,
    required this.voteDurationSeconds,
    required this.roundResultBreakSeconds,
    required this.reconnectGraceSeconds,
  });

  final int roundDurationSeconds;
  final int roundsPerGame;
  final int voteDurationSeconds;
  final int roundResultBreakSeconds;
  final int reconnectGraceSeconds;

  static const fallback = TimingConfig(
    roundDurationSeconds: 40,
    roundsPerGame: 5,
    voteDurationSeconds: 5,
    roundResultBreakSeconds: 5,
    reconnectGraceSeconds: 60,
  );

  /// The client may override round duration in this range when creating a
  /// room (matches the server's documented 10–180 clamp).
  static const roundDurationMin = 10;
  static const roundDurationMax = 180;

  factory TimingConfig.fromJson(Map<String, dynamic> json) {
    const f = fallback;
    return TimingConfig(
      roundDurationSeconds: _asInt(json['roundDurationSeconds'], f.roundDurationSeconds,
          min: roundDurationMin, max: roundDurationMax),
      roundsPerGame: _asInt(json['roundsPerGame'], f.roundsPerGame, min: 1, max: 50),
      voteDurationSeconds: _asInt(json['voteDurationSeconds'], f.voteDurationSeconds, min: 1, max: 120),
      roundResultBreakSeconds:
          _asInt(json['roundResultBreakSeconds'], f.roundResultBreakSeconds, min: 0, max: 120),
      reconnectGraceSeconds:
          _asInt(json['reconnectGraceSeconds'], f.reconnectGraceSeconds, min: 0, max: 600),
    );
  }
}

/// Player-level curve. Level is a pure function of cumulative total score:
///   score to reach level L = basePoints * (L - 1) * L / 2   (quadratic)
///   level for a score       = floor((1 + sqrt(1 + 8*score/basePoints)) / 2)
/// clamped to [1, maxLevel]. This matches the server's `game/leveling.ts`
/// exactly — see [levelForScore].
class LevelingConfig {
  const LevelingConfig({required this.basePoints, required this.maxLevel});

  final int basePoints;
  final int maxLevel;

  static const fallback = LevelingConfig(basePoints: 100, maxLevel: 100);

  factory LevelingConfig.fromJson(Map<String, dynamic> json) {
    const f = fallback;
    return LevelingConfig(
      // basePoints drives a division — never let it reach 0.
      basePoints: _asInt(json['basePoints'], f.basePoints, min: 1, max: 100000),
      maxLevel: _asInt(json['maxLevel'], f.maxLevel, min: 1, max: 10000),
    );
  }

  /// Cumulative score needed to *reach* [level].
  int thresholdForLevel(int level) {
    if (level <= 1) return 0;
    final l = level > maxLevel ? maxLevel : level;
    return (basePoints * (l - 1) * l) ~/ 2;
  }

  /// Level a given cumulative [score] maps to, clamped to [1, maxLevel].
  int levelForScore(int score) {
    final s = score < 0 ? 0 : score;
    final n = ((1 + math.sqrt(1 + 8 * s / basePoints)) / 2).floor();
    if (n < 1) return 1;
    if (n > maxLevel) return maxLevel;
    return n;
  }
}

/// The whole gameplay-numbers payload, assembled from the sub-blocks above.
class ClientConfig {
  const ClientConfig({
    required this.economy,
    required this.onlineGame,
    required this.scoring,
    required this.timing,
    required this.leveling,
  });

  final Economy economy;
  final OnlineGameConfig onlineGame;
  final ScoringConfig scoring;
  final TimingConfig timing;
  final LevelingConfig leveling;

  /// All compiled defaults. This is what the app uses before the first
  /// successful `GET /config/client` and if that fetch fails.
  static const fallback = ClientConfig(
    economy: Economy.fallback,
    onlineGame: OnlineGameConfig.fallback,
    scoring: ScoringConfig.fallback,
    timing: TimingConfig.fallback,
    leveling: LevelingConfig.fallback,
  );

  /// Parses the gameplay-numbers blocks out of the full `GET /config/client`
  /// body. Missing blocks fall back to defaults, never throw.
  factory ClientConfig.fromJson(Map<String, dynamic> json) {
    return ClientConfig(
      economy: Economy.fromJson(_asMap(json['economy'])),
      onlineGame: OnlineGameConfig.fromJson(_asMap(json['onlineGame'])),
      scoring: ScoringConfig.fromJson(_asMap(json['scoring'])),
      timing: TimingConfig.fromJson(_asMap(json['timing'])),
      leveling: LevelingConfig.fromJson(_asMap(json['leveling'])),
    );
  }
}
