import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../models/round.dart';
import 'auth_provider.dart';
import 'room_provider.dart';
import 'socket_provider.dart';

enum RoundPhase { waitingForRound, inRound, waitingForOthers, voting, result, gameOver }

/// A single reaction sticker broadcast to the room — ephemeral, not stored
/// server-side, and re-wrapped with a fresh identity each time so the UI
/// can tell repeated identical reactions apart (e.g. two 🔥 in a row).
class ReactionEvent {
  ReactionEvent({required this.playerId, required this.stickerId, required this.at});

  final String playerId;
  final String stickerId;
  final int at;
}

class RoundControllerState {
  const RoundControllerState({
    this.phase = RoundPhase.waitingForRound,
    this.currentRound,
    this.submittedPlayerIds = const [],
    this.activeVote,
    this.lastVoteResult,
    this.lastResult,
    this.finalScoreboard,
    this.incomingReaction,
    this.hintsUsedInRound = 0,
    this.extraTimeUsed = false,
    this.timeoutBonusUsed = false,
  });

  final RoundPhase phase;
  final RoundStart? currentRound;
  final List<String> submittedPlayerIds;
  final VoteStart? activeVote;
  final VoteResult? lastVoteResult;
  final RoundResult? lastResult;
  final List<ScoreboardEntry>? finalScoreboard;
  final ReactionEvent? incomingReaction;
  final int hintsUsedInRound;
  final bool extraTimeUsed;
  final bool timeoutBonusUsed;

  RoundControllerState copyWith({
    RoundPhase? phase,
    RoundStart? currentRound,
    List<String>? submittedPlayerIds,
    VoteStart? activeVote,
    VoteResult? lastVoteResult,
    RoundResult? lastResult,
    List<ScoreboardEntry>? finalScoreboard,
    ReactionEvent? incomingReaction,
    int? hintsUsedInRound,
    bool? extraTimeUsed,
    bool? timeoutBonusUsed,
    bool clearActiveVote = false,
  }) {
    return RoundControllerState(
      phase: phase ?? this.phase,
      currentRound: currentRound ?? this.currentRound,
      submittedPlayerIds: submittedPlayerIds ?? this.submittedPlayerIds,
      activeVote: clearActiveVote ? null : (activeVote ?? this.activeVote),
      lastVoteResult: lastVoteResult ?? this.lastVoteResult,
      lastResult: lastResult ?? this.lastResult,
      finalScoreboard: finalScoreboard ?? this.finalScoreboard,
      incomingReaction: incomingReaction ?? this.incomingReaction,
      hintsUsedInRound: hintsUsedInRound ?? this.hintsUsedInRound,
      extraTimeUsed: extraTimeUsed ?? this.extraTimeUsed,
      timeoutBonusUsed: timeoutBonusUsed ?? this.timeoutBonusUsed,
    );
  }

  static const initial = RoundControllerState();
}

/// Owns round-in-progress state: the live letter/categories/deadline from
/// `roundStart`, who has submitted so far, and the eventual `roundResult`/
/// `gameOver`.
class RoundController extends StateNotifier<RoundControllerState> {
  RoundController(this._ref) : super(RoundControllerState.initial) {
    final socket = _ref.read(socketServiceProvider);
    socket.on('roundStart', _onRoundStart);
    socket.on('waitingForOthers', _onWaitingForOthers);
    socket.on('voteStart', _onVoteStart);
    socket.on('voteResult', _onVoteResult);
    socket.on('roundResult', _onRoundResult);
    socket.on('gameOver', _onGameOver);
    socket.on('reactionBroadcast', _onReactionBroadcast);
  }

  final Ref _ref;

  void _onRoundStart(dynamic data) {
    final json = (data as Map).cast<String, dynamic>();
    state = RoundControllerState(
      phase: RoundPhase.inRound,
      currentRound: RoundStart.fromJson(json),
      hintsUsedInRound: 0,
      extraTimeUsed: false,
      timeoutBonusUsed: false,
    );
  }

  void _onWaitingForOthers(dynamic data) {
    final json = (data as Map).cast<String, dynamic>();
    final ids = ((json['submittedPlayerIds'] as List?) ?? const []).cast<String>();
    final myId = _ref.read(roomControllerProvider).myPlayerId;
    final iSubmitted = myId != null && ids.contains(myId);
    state = state.copyWith(
      submittedPlayerIds: ids,
      phase: iSubmitted ? RoundPhase.waitingForOthers : state.phase,
    );
  }

  void _onVoteStart(dynamic data) {
    final json = (data as Map).cast<String, dynamic>();
    state = state.copyWith(phase: RoundPhase.voting, activeVote: VoteStart.fromJson(json));
  }

  void _onVoteResult(dynamic data) {
    final json = (data as Map).cast<String, dynamic>();
    state = state.copyWith(lastVoteResult: VoteResult.fromJson(json), clearActiveVote: true);
  }

  void _onRoundResult(dynamic data) {
    final json = (data as Map).cast<String, dynamic>();
    final result = RoundResult.fromJson(json);
    state = state.copyWith(phase: RoundPhase.result, lastResult: result, submittedPlayerIds: const []);
  }

  void _onGameOver(dynamic data) {
    final json = (data as Map).cast<String, dynamic>();
    final scoreboard = ((json['scoreboard'] as List?) ?? const [])
        .map((e) => ScoreboardEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    final coinBalance = (json['coinBalance'] as num?)?.toInt();
    if (coinBalance != null) {
      _ref.read(authControllerProvider.notifier).updateCoinBalance(coinBalance);
    }
    state = state.copyWith(phase: RoundPhase.gameOver, finalScoreboard: scoreboard);
  }

  void _onReactionBroadcast(dynamic data) {
    final json = (data as Map).cast<String, dynamic>();
    state = state.copyWith(
      incomingReaction: ReactionEvent(
        playerId: json['playerId'] as String,
        stickerId: json['stickerId'] as String,
        at: (json['at'] as num).toInt(),
      ),
    );
  }

  void sendReaction(String roomCode, String stickerId) {
    _ref.read(socketServiceProvider).emit('sendReaction', {'code': roomCode, 'stickerId': stickerId});
  }

  /// Request word hint for [category] (or null for random empty) for progressive coins (300/600/1200).
  Future<Map<String, dynamic>?> requestHint(String roomCode, {CategoryId? category}) async {
    final round = state.currentRound;
    if (round == null || state.hintsUsedInRound >= 3) return null;

    final socket = _ref.read(socketServiceProvider);
    final completer = Completer<dynamic>();
    socket.once('hintResult', (data) {
      if (!completer.isCompleted) completer.complete(data);
    });

    final cost = state.hintsUsedInRound == 0 ? 300 : (state.hintsUsedInRound == 1 ? 600 : 1200);

    socket.emit('useHint', {
      'code': roomCode,
      'roundId': round.roundIndex,
      if (category != null) 'category': category.wireId,
    });

    try {
      final data = await completer.future.timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (data is Map) {
        final json = data.cast<String, dynamic>();
        if (json['success'] == true) {
          final hintsUsed = (json['hintsUsedInRound'] as num?)?.toInt() ?? (state.hintsUsedInRound + 1);
          final remCoins = (json['remainingCoins'] as num?)?.toInt();
          if (remCoins != null) {
            _ref.read(authControllerProvider.notifier).updateCoinBalance(remCoins);
          } else {
            // Optimistic fallback deduction in case backend omitted remainingCoins
            final currentCoins = _ref.read(authControllerProvider).player?.coinBalance ?? 0;
            _ref.read(authControllerProvider.notifier).updateCoinBalance((currentCoins - cost).clamp(0, 999999999));
          }
          state = state.copyWith(hintsUsedInRound: hintsUsed);
          return json;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Request 20s extra time using stopwatch power-up for 300 coins (once per round).
  Future<bool> requestExtraTime(String roomCode) async {
    final round = state.currentRound;
    if (round == null || state.extraTimeUsed) return false;

    final socket = _ref.read(socketServiceProvider);
    final completer = Completer<dynamic>();
    socket.once('extraTimeGranted', (data) {
      if (!completer.isCompleted) completer.complete(data);
    });

    socket.emit('useExtraTime', {
      'code': roomCode,
      'roundId': round.roundIndex,
    });

    try {
      final data = await completer.future.timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (data is Map) {
        final json = data.cast<String, dynamic>();
        if (json['success'] == true) {
          final remCoins = (json['remainingCoins'] as num?)?.toInt();
          if (remCoins != null) {
            _ref.read(authControllerProvider.notifier).updateCoinBalance(remCoins);
          } else {
            final currentCoins = _ref.read(authControllerProvider).player?.coinBalance ?? 0;
            _ref.read(authControllerProvider.notifier).updateCoinBalance((currentCoins - 300).clamp(0, 999999999));
          }

          final newDeadline = (json['newDeadline'] as num?)?.toInt();
          if (newDeadline != null && state.currentRound != null) {
            state = state.copyWith(
              extraTimeUsed: true,
              currentRound: state.currentRound!.copyWith(deadline: newDeadline),
            );
          } else {
            state = state.copyWith(extraTimeUsed: true);
          }
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Claim timeout bonus (+20s and 1 word hint) after watching rewarded video.
  Future<Map<String, dynamic>?> claimTimeoutBonus(String roomCode) async {
    final round = state.currentRound;
    if (round == null || state.timeoutBonusUsed) return null;

    final socket = _ref.read(socketServiceProvider);
    final completer = Completer<dynamic>();
    socket.once('timeoutBonusGranted', (data) {
      if (!completer.isCompleted) completer.complete(data);
    });

    socket.emit('claimTimeoutBonus', {
      'code': roomCode,
      'roundId': round.roundIndex,
    });

    try {
      final data = await completer.future.timeout(const Duration(seconds: 4), onTimeout: () => null);
      if (data is Map) {
        final json = data.cast<String, dynamic>();
        if (json['success'] == true) {
          final newDeadline = (json['newDeadline'] as num?)?.toInt() ?? (round.deadline + 20000);
          final now = DateTime.now().millisecondsSinceEpoch;
          state = state.copyWith(
            timeoutBonusUsed: true,
            currentRound: round.copyWith(
              deadline: newDeadline,
              serverTime: now,
              receivedAt: now,
            ),
          );
          return json;
        }
      }
    } catch (_) {}

    // Fallback: If server hasn't implemented claimTimeoutBonus yet or socket timed out,
    // grant local 20s extension so user doesn't get blocked after watching full ad
    final now = DateTime.now().millisecondsSinceEpoch;
    final fallbackDeadline = now + 20000;
    state = state.copyWith(
      timeoutBonusUsed: true,
      currentRound: round.copyWith(
        deadline: fallbackDeadline,
        serverTime: now,
        receivedAt: now,
      ),
    );
    return {'success': true, 'newDeadline': fallbackDeadline};
  }

  void submitAnswers(String roomCode, Map<CategoryId, String> answers) {
    final round = state.currentRound;
    if (round == null) return;
    final wire = answers.map((k, v) => MapEntry(k.wireId, v));
    _ref.read(socketServiceProvider).emit('submitAnswers', {
      'code': roomCode,
      'roundId': round.roundIndex,
      'answers': wire,
    });
  }

  void castVote(String roomCode, String voteId, bool accept) {
    _ref.read(socketServiceProvider).emit('voteOnWord', {
      'code': roomCode,
      'voteId': voteId,
      'accept': accept,
    });
  }

  void requestNextRound(String roomCode) {
    _ref.read(socketServiceProvider).emit('nextRound', {'code': roomCode});
  }

  void reset() {
    state = RoundControllerState.initial;
  }
}

final roundControllerProvider = StateNotifierProvider<RoundController, RoundControllerState>((ref) {
  return RoundController(ref);
});
