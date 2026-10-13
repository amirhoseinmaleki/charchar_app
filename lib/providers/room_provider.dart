import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/room.dart';
import '../models/room_events.dart';
import 'auth_provider.dart';
import 'socket_provider.dart';

class RoomControllerState {
  const RoomControllerState({this.room, this.myPlayerId, this.isBusy = false});

  final RoomSnapshot? room;
  final String? myPlayerId;
  final bool isBusy;

  RoomControllerState copyWith({RoomSnapshot? room, String? myPlayerId, bool? isBusy}) {
    return RoomControllerState(
      room: room ?? this.room,
      myPlayerId: myPlayerId ?? this.myPlayerId,
      isBusy: isBusy ?? this.isBusy,
    );
  }

  static const initial = RoomControllerState();
}

/// Owns the lobby/room lifecycle: create/join/leave/startGame and the live
/// `roomUpdate` snapshot. Round/vote/result state is handled by separate
/// controllers built in later phases — this one only covers the lobby.
class RoomController extends StateNotifier<RoomControllerState> {
  RoomController(this._ref) : super(RoomControllerState.initial) {
    final socket = _ref.read(socketServiceProvider);
    socket.on('roomUpdate', _onRoomUpdate);
    socket.on('roomCreated', _onRoomCreatedOrJoined);
    socket.on('roomJoined', _onRoomCreatedOrJoined);
  }

  final Ref _ref;

  void _onRoomUpdate(dynamic data) {
    final json = (data as Map).cast<String, dynamic>();
    state = state.copyWith(room: RoomSnapshot.fromJson(json));
  }

  void _onRoomCreatedOrJoined(dynamic data) {
    final json = (data as Map).cast<String, dynamic>();
    final playerId = json['playerId'] as String;
    final coinBalance = (json['coinBalance'] as num?)?.toInt();
    state = state.copyWith(myPlayerId: playerId);
    if (coinBalance != null) {
      _ref.read(authControllerProvider.notifier).updateCoinBalance(coinBalance);
    }
  }

  Future<String> createRoom() => _emitAndAwait(
        emitEvent: 'createRoom',
        emitPayload: const {},
        successEvent: 'roomCreated',
        extractResult: (json) => json['code'] as String,
      );

  Future<String> joinRoom(String code) => _emitAndAwait(
        emitEvent: 'joinRoom',
        emitPayload: {'code': code.trim().toUpperCase()},
        successEvent: 'roomJoined',
        extractResult: (json) => json['code'] as String,
      );

  /// Starts "بازی سریع" — a free solo game against 1-3 NPC opponents. No
  /// coin cost, no lobby wait: the server creates the room and immediately
  /// starts the first round, so the caller should navigate straight to
  /// `/round` once this resolves rather than to `/lobby`.
  Future<String> startSoloGame({int npcCount = 2}) => _emitAndAwait(
        emitEvent: 'startSoloGame',
        emitPayload: {'npcCount': npcCount},
        successEvent: 'roomCreated',
        extractResult: (json) => json['code'] as String,
      );

  /// Creates a "بازی آنلاین" quick-match: costs a flat coin fee, joins a
  /// lobby that server-side fills with disguised NPCs up to 3-5 players,
  /// then auto-starts. The caller should navigate to `/lobby` on success —
  /// unlike بازی سریع this one does show a (briefly) filling lobby before
  /// the round starts, since the whole point is to feel like a real match.
  Future<String> createOnlineGame({required int roundsPerGame}) => _emitAndAwait(
        emitEvent: 'createOnlineGame',
        emitPayload: {'roundsPerGame': roundsPerGame},
        successEvent: 'roomCreated',
        extractResult: (json) => json['code'] as String,
      );

  void leaveRoom() {
    final code = state.room?.code;
    if (code == null) return;
    _ref.read(socketServiceProvider).emit('leaveRoom', {'code': code});
    state = RoomControllerState.initial;
  }

  void startGame() {
    final code = state.room?.code;
    if (code == null) return;
    _ref.read(socketServiceProvider).emit('startGame', {'code': code});
  }

  /// Emits a socket event and races its declared success/error/
  /// insufficient-coins responses, resolving or throwing accordingly.
  /// Centralizes the create/join request-response pattern so screens don't
  /// each hand-roll their own listener bookkeeping.
  Future<T> _emitAndAwait<T>({
    required String emitEvent,
    required Map<String, dynamic> emitPayload,
    required String successEvent,
    required T Function(Map<String, dynamic> json) extractResult,
  }) async {
    final socket = _ref.read(socketServiceProvider);
    state = state.copyWith(isBusy: true);

    final completer = Completer<T>();

    void onSuccess(dynamic data) {
      if (completer.isCompleted) return;
      final json = (data as Map).cast<String, dynamic>();
      completer.complete(extractResult(json));
    }

    void onError(dynamic data) {
      if (completer.isCompleted) return;
      final json = (data as Map).cast<String, dynamic>();
      completer.completeError(RoomException(json['code'] as String, json['message'] as String));
    }

    void onInsufficientCoins(dynamic data) {
      if (completer.isCompleted) return;
      final json = (data as Map).cast<String, dynamic>();
      final info = InsufficientCoinsInfo.fromJson(json);
      completer.completeError(
        RoomException('INSUFFICIENT_COINS', 'سکه کافی ندارید. نیاز: ${info.required}, موجودی: ${info.balance}'),
      );
    }

    socket.once(successEvent, onSuccess);
    socket.once('errorEvent', onError);
    socket.once('insufficientCoins', onInsufficientCoins);

    try {
      socket.emit(emitEvent, emitPayload);
      final result = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw const RoomException('SERVER_UNREACHABLE', 'ارتباط با سرور برقرار نشد.'),
      );
      return result;
    } finally {
      socket.off(successEvent, onSuccess);
      socket.off('errorEvent', onError);
      socket.off('insufficientCoins', onInsufficientCoins);
      state = state.copyWith(isBusy: false);
    }
  }
}

final roomControllerProvider = StateNotifierProvider<RoomController, RoomControllerState>((ref) {
  return RoomController(ref);
});
