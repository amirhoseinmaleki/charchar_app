import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/socket_service.dart';
import 'auth_provider.dart';
import 'room_provider.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();
  ref.onDispose(service.dispose);
  return service;
});

final connectionStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  final service = ref.watch(socketServiceProvider);
  return service.statusStream;
});

/// A rejected handshake (stale/invalid session token — e.g. the backing
/// player record no longer exists after a database reset) can never be
/// fixed by retrying the socket connection. Force a clean logout so the
/// router sends the player back to Login instead of leaving them stuck on
/// a screen that says "در حال بررسی" forever. Read once near app start
/// (see main.dart) so this listener is always armed.
final unauthorizedSocketWatcherProvider = Provider<void>((ref) {
  ref.listen(connectionStatusProvider, (previous, next) {
    if (next.valueOrNull == ConnectionStatus.unauthorized) {
      ref.read(authControllerProvider.notifier).logout();
    }
  });
});

/// Keeps the socket connected whenever a session token is available,
/// independent of which screen happens to be mounted — connecting only
/// from a single screen's initState (e.g. Home) misses the case where the
/// token becomes available *after* that screen already built (session
/// restore is async) or where the user is elsewhere when a reconnect is
/// needed. Read once near app start (see main.dart).
final socketAutoConnectProvider = Provider<void>((ref) {
  String? connectedWithToken;
  ref.listen(authControllerProvider, (previous, next) {
    final token = next.token;
    if (token == null || token == connectedWithToken) return;
    connectedWithToken = token;
    ref.read(socketServiceProvider).connect(token);
  }, fireImmediately: true);
});

/// Re-syncs room/round state after the underlying socket reconnects mid-game
/// (a real disconnect→reconnect, not the very first connect after login).
///
/// Without this, a player whose connection blipped for even a moment while
/// in an online-game lobby (or mid-round/mid-vote) would never receive the
/// `roundStart`/`voteStart` event that already fired while they were briefly
/// offline — Socket.io only delivers events broadcast *after* a socket
/// (re)joins its rooms, not ones it missed — leaving them stuck on stale
/// lobby/round UI forever even though the game moved on server-side. The
/// server's `reconnectToRoom` handler re-sends whatever's currently in
/// flight for that room, so the client's existing event listeners recover
/// on their own once this fires. Read once near app start (see main.dart).
final socketReconnectResyncProvider = Provider<void>((ref) {
  var hasSeenDisconnect = false;
  ref.listen(connectionStatusProvider, (previous, next) {
    final status = next.valueOrNull;
    if (status == ConnectionStatus.disconnected || status == ConnectionStatus.reconnecting) {
      hasSeenDisconnect = true;
      return;
    }
    if (status == ConnectionStatus.connected && hasSeenDisconnect) {
      hasSeenDisconnect = false;
      final roomCode = ref.read(roomControllerProvider).room?.code;
      if (roomCode != null) {
        ref.read(socketServiceProvider).emit('reconnectToRoom', {'code': roomCode});
      }
    }
  });
});
