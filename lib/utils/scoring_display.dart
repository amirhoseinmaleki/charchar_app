import '../models/round.dart';

/// Visual tier for a judged word, used to pick gold/silver/gray styling
/// before the authoritative [RoundResult] arrives. This is a display-only
/// mirror of the server's scoring rule (see `GET /config/client` →
/// `scoring`: pointsUnique / pointsShared / pointsInvalid) — the server
/// result is always authoritative and overwrites any optimistic guess made
/// here.
enum ScoreTier { unique, shared, invalid, pending }

ScoreTier scoreTierFor(WordJudgement judgement) {
  switch (judgement.verdict) {
    case WordVerdict.pendingVote:
      return ScoreTier.pending;
    case WordVerdict.invalid:
      return ScoreTier.invalid;
    case WordVerdict.valid:
      return judgement.sharedWith.isEmpty ? ScoreTier.unique : ScoreTier.shared;
  }
}

/// Optimistic guess at a word's tier before the server responds, based only
/// on whether the locally-typed word matches another player's answer that
/// this client can already see (e.g. after a reveal). Given no dictionary
/// access client-side, "unknown" words are optimistically treated as
/// pending rather than assumed valid or invalid.
ScoreTier optimisticTierFor({required String word, required List<String> othersWords}) {
  final trimmed = word.trim();
  if (trimmed.isEmpty) return ScoreTier.invalid;
  final isShared = othersWords.any((w) => w.trim() == trimmed);
  return isShared ? ScoreTier.shared : ScoreTier.pending;
}

int sumScoreForPlayer(List<WordJudgement> judgements, String playerId) {
  return judgements.where((j) => j.playerId == playerId).fold(0, (sum, j) => sum + j.points);
}

List<ScoreboardEntry> sortScoreboardDescending(List<ScoreboardEntry> entries) {
  final copy = [...entries];
  copy.sort((a, b) => b.score.compareTo(a.score));
  return copy;
}
