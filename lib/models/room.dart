import 'category.dart';
import 'player.dart';

enum RoomStatus { lobby, inRound, roundResult, voting, gameOver }

RoomStatus roomStatusFromWire(String wire) {
  switch (wire) {
    case 'lobby':
      return RoomStatus.lobby;
    case 'in_round':
      return RoomStatus.inRound;
    case 'round_result':
      return RoomStatus.roundResult;
    case 'voting':
      return RoomStatus.voting;
    case 'game_over':
      return RoomStatus.gameOver;
    default:
      return RoomStatus.lobby;
  }
}

class RoomSettings {
  const RoomSettings({required this.categories, required this.roundsPerGame, required this.roundDurationSeconds});

  final List<CategoryId> categories;
  final int roundsPerGame;
  final int roundDurationSeconds;

  factory RoomSettings.fromJson(Map<String, dynamic> json) {
    return RoomSettings(
      categories: ((json['categories'] as List?) ?? const [])
          .map((e) => CategoryIdX.fromWire(e as String))
          .toList(),
      roundsPerGame: (json['roundsPerGame'] as num?)?.toInt() ?? 5,
      roundDurationSeconds: (json['roundDurationSeconds'] as num?)?.toInt() ?? 75,
    );
  }
}

class RoomSnapshot {
  const RoomSnapshot({
    required this.code,
    required this.status,
    required this.hostId,
    required this.players,
    required this.settings,
    required this.currentRoundIndex,
    required this.isSoloGame,
    required this.isOnlineGame,
  });

  final String code;
  final RoomStatus status;
  final String hostId;
  final List<Player> players;
  final RoomSettings settings;
  final int? currentRoundIndex;

  /// True only for "بازی سریع" (honest solo NPC mode). False for ordinary
  /// multiplayer rooms *and* for "بازی آنلاین" — the server deliberately
  /// never reports isNpc:true for disguised online-game opponents, so this
  /// flag (not `isNpc`) is what the UI should use to decide whether to
  /// show an NPC badge at all.
  final bool isSoloGame;

  /// True for "بازی آنلاین" quick-match rooms — the server auto-starts and
  /// auto-advances these, so the UI should skip manual host controls
  /// (start-game button, "next round" button) for them.
  final bool isOnlineGame;

  factory RoomSnapshot.fromJson(Map<String, dynamic> json) {
    final roomJson = (json['room'] as Map?)?.cast<String, dynamic>() ?? json;
    return RoomSnapshot(
      code: roomJson['code'] as String,
      status: roomStatusFromWire(roomJson['status'] as String),
      hostId: roomJson['hostId'] as String,
      players: ((roomJson['players'] as List?) ?? const [])
          .map((e) => Player.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      settings: RoomSettings.fromJson((roomJson['settings'] as Map).cast<String, dynamic>()),
      currentRoundIndex: (roomJson['currentRoundIndex'] as num?)?.toInt(),
      isSoloGame: roomJson['isSoloGame'] as bool? ?? false,
      isOnlineGame: roomJson['isOnlineGame'] as bool? ?? false,
    );
  }
}
