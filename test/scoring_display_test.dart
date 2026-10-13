import 'package:flutter_test/flutter_test.dart';
import 'package:esmvafamilyar/models/category.dart';
import 'package:esmvafamilyar/models/round.dart';
import 'package:esmvafamilyar/utils/scoring_display.dart';

WordJudgement judgement({
  String playerId = 'p1',
  CategoryId category = CategoryId.animal,
  String word = 'اسب',
  WordVerdict verdict = WordVerdict.valid,
  int points = 10,
  List<String> sharedWith = const [],
}) {
  return WordJudgement(
    playerId: playerId,
    category: category,
    word: word,
    verdict: verdict,
    points: points,
    sharedWith: sharedWith,
  );
}

void main() {
  group('scoreTierFor', () {
    test('unique valid word is gold tier', () {
      final j = judgement(verdict: WordVerdict.valid, points: 10, sharedWith: const []);
      expect(scoreTierFor(j), ScoreTier.unique);
    });

    test('shared valid word is silver tier', () {
      final j = judgement(verdict: WordVerdict.valid, points: 5, sharedWith: const ['p2']);
      expect(scoreTierFor(j), ScoreTier.shared);
    });

    test('invalid word is invalid tier', () {
      final j = judgement(verdict: WordVerdict.invalid, points: 0);
      expect(scoreTierFor(j), ScoreTier.invalid);
    });

    test('pending_vote word is pending tier', () {
      final j = judgement(verdict: WordVerdict.pendingVote, points: 0);
      expect(scoreTierFor(j), ScoreTier.pending);
    });
  });

  group('optimisticTierFor', () {
    test('empty word is optimistically invalid', () {
      expect(optimisticTierFor(word: '', othersWords: const []), ScoreTier.invalid);
    });

    test('word matching another visible answer is optimistically shared', () {
      expect(optimisticTierFor(word: 'اسب', othersWords: const ['اسب', 'ببر']), ScoreTier.shared);
    });

    test('word with no known match is optimistically pending, never assumed valid', () {
      expect(optimisticTierFor(word: 'اسب', othersWords: const ['ببر']), ScoreTier.pending);
    });
  });

  group('sumScoreForPlayer', () {
    test('sums only the given player judgements', () {
      final judgements = [
        judgement(playerId: 'p1', points: 10),
        judgement(playerId: 'p1', points: 5),
        judgement(playerId: 'p2', points: 10),
      ];
      expect(sumScoreForPlayer(judgements, 'p1'), 15);
    });
  });

  group('sortScoreboardDescending', () {
    test('orders by score descending without mutating input', () {
      final entries = [
        const ScoreboardEntry(playerId: 'a', name: 'A', score: 5, isNpc: false),
        const ScoreboardEntry(playerId: 'b', name: 'B', score: 20, isNpc: false),
        const ScoreboardEntry(playerId: 'c', name: 'C', score: 10, isNpc: false),
      ];
      final sorted = sortScoreboardDescending(entries);
      expect(sorted.map((e) => e.playerId).toList(), ['b', 'c', 'a']);
      expect(entries[0].playerId, 'a'); // original untouched
    });
  });
}
