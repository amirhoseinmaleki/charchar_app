import 'category.dart';

class RoundStart {
  const RoundStart({
    required this.roundIndex,
    required this.letter,
    required this.categories,
    required this.deadline,
    required this.serverTime,
    required this.receivedAt,
  });

  final int roundIndex;
  final String letter;
  final List<CategoryId> categories;
  final int deadline; // epoch ms, server-authoritative
  final int serverTime; // epoch ms on the server when it sent this
  /// epoch ms on THIS device the moment the roundStart event was received.
  /// Paired with [serverTime] it gives the client↔server clock offset, so
  /// the countdown can be driven purely from "ms remaining at receipt"
  /// instead of comparing a server timestamp to the local clock.
  final int receivedAt;

  /// Milliseconds left in the round at the instant this event was received,
  /// clock-skew corrected: (deadline - serverTime) is the true remaining
  /// span per the server; we trust that and count down locally from here.
  int get remainingMsAtReceipt => (deadline - serverTime).clamp(0, 1 << 31);

  /// The wall-clock instant (local) the round should end — [receivedAt]
  /// plus the skew-corrected remaining span.
  DateTime get localDeadline =>
      DateTime.fromMillisecondsSinceEpoch(receivedAt + remainingMsAtReceipt);

  RoundStart copyWith({
    int? roundIndex,
    String? letter,
    List<CategoryId>? categories,
    int? deadline,
    int? serverTime,
    int? receivedAt,
  }) {
    return RoundStart(
      roundIndex: roundIndex ?? this.roundIndex,
      letter: letter ?? this.letter,
      categories: categories ?? this.categories,
      deadline: deadline ?? this.deadline,
      serverTime: serverTime ?? this.serverTime,
      receivedAt: receivedAt ?? this.receivedAt,
    );
  }

  factory RoundStart.fromJson(Map<String, dynamic> json) {
    return RoundStart(
      roundIndex: (json['roundIndex'] as num).toInt(),
      letter: json['letter'] as String,
      categories: ((json['categories'] as List?) ?? const [])
          .map((e) => CategoryIdX.fromWire(e as String))
          .toList(),
      deadline: (json['deadline'] as num).toInt(),
      serverTime: (json['serverTime'] as num).toInt(),
      receivedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

enum WordVerdict { valid, invalid, pendingVote }

WordVerdict wordVerdictFromWire(String wire) {
  switch (wire) {
    case 'valid':
      return WordVerdict.valid;
    case 'pending_vote':
      return WordVerdict.pendingVote;
    default:
      return WordVerdict.invalid;
  }
}

class WordJudgement {
  const WordJudgement({
    required this.playerId,
    required this.category,
    required this.word,
    required this.verdict,
    required this.points,
    required this.sharedWith,
  });

  final String playerId;
  final CategoryId category;
  final String word;
  final WordVerdict verdict;
  final int points;
  final List<String> sharedWith;

  factory WordJudgement.fromJson(Map<String, dynamic> json) {
    return WordJudgement(
      playerId: json['playerId'] as String,
      category: CategoryIdX.fromWire(json['category'] as String),
      word: json['word'] as String? ?? '',
      verdict: wordVerdictFromWire(json['verdict'] as String),
      points: (json['points'] as num?)?.toInt() ?? 0,
      sharedWith: ((json['sharedWith'] as List?) ?? const []).cast<String>(),
    );
  }
}

class ScoreboardEntry {
  const ScoreboardEntry({
    required this.playerId,
    required this.name,
    required this.score,
    required this.isNpc,
    this.nameColorHex,
    this.avatarUrl,
  });

  final String playerId;
  final String name;
  final int score;
  final bool isNpc;

  /// Server-resolved hex for this player's equipped name-color (null =
  /// default). Use with [ColoredName].
  final String? nameColorHex;

  /// Server-relative path for this player's equipped avatar image.
  final String? avatarUrl;

  factory ScoreboardEntry.fromJson(Map<String, dynamic> json) {
    return ScoreboardEntry(
      playerId: json['playerId'] as String,
      name: json['name'] as String,
      score: (json['score'] as num?)?.toInt() ?? 0,
      isNpc: json['isNpc'] as bool? ?? false,
      nameColorHex: json['nameColorHex'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class VoteStart {
  const VoteStart({
    required this.voteId,
    required this.category,
    required this.word,
    required this.authorPlayerIds,
    required this.deadline,
  });

  final String voteId;
  final CategoryId category;
  final String word;
  final List<String> authorPlayerIds;
  final int deadline; // epoch ms, server-authoritative

  factory VoteStart.fromJson(Map<String, dynamic> json) {
    return VoteStart(
      voteId: json['voteId'] as String,
      category: CategoryIdX.fromWire(json['category'] as String),
      word: json['word'] as String? ?? '',
      authorPlayerIds: ((json['authorPlayerIds'] as List?) ?? const []).cast<String>(),
      deadline: (json['deadline'] as num).toInt(),
    );
  }
}

class VoteResult {
  const VoteResult({
    required this.voteId,
    required this.category,
    required this.word,
    required this.accepted,
    required this.yes,
    required this.no,
    required this.updatedJudgements,
    required this.scoreboard,
  });

  final String voteId;
  final CategoryId category;
  final String word;
  final bool accepted;
  final int yes;
  final int no;
  final List<WordJudgement> updatedJudgements;
  final List<ScoreboardEntry> scoreboard;

  factory VoteResult.fromJson(Map<String, dynamic> json) {
    return VoteResult(
      voteId: json['voteId'] as String,
      category: CategoryIdX.fromWire(json['category'] as String),
      word: json['word'] as String? ?? '',
      accepted: json['accepted'] as bool? ?? false,
      yes: (json['yes'] as num?)?.toInt() ?? 0,
      no: (json['no'] as num?)?.toInt() ?? 0,
      updatedJudgements: ((json['updatedJudgements'] as List?) ?? const [])
          .map((e) => WordJudgement.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      scoreboard: ((json['scoreboard'] as List?) ?? const [])
          .map((e) => ScoreboardEntry.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

class RoundResult {
  const RoundResult({
    required this.roundIndex,
    required this.judgements,
    required this.scoreboard,
  });

  final int roundIndex;
  final List<WordJudgement> judgements;
  final List<ScoreboardEntry> scoreboard;

  factory RoundResult.fromJson(Map<String, dynamic> json) {
    return RoundResult(
      roundIndex: (json['roundIndex'] as num).toInt(),
      judgements: ((json['judgements'] as List?) ?? const [])
          .map((e) => WordJudgement.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      scoreboard: ((json['scoreboard'] as List?) ?? const [])
          .map((e) => ScoreboardEntry.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}
