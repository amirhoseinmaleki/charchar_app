import '../services/socket_service.dart';

/// UI-facing reconnect states derived from raw [ConnectionStatus] plus
/// whether the app currently has an active room session to rejoin. Kept as
/// a pure state machine (no socket/timer side effects) so it can be unit
/// tested directly.
enum ReconnectUiState {
  /// Not in a room session; connection status is irrelevant to reconnect UI.
  idle,

  /// Actively connected and in a room — nothing to show.
  stable,

  /// Lost connection while in a room; attempting automatic reconnect.
  reconnecting,

  /// Reconnect attempts exhausted or explicitly gave up.
  failed,

  /// The session token was rejected — no amount of retrying will help;
  /// the app must send the player back to Login to re-authenticate.
  sessionExpired,
}

class ReconnectStateMachine {
  ReconnectStateMachine({this.maxAttempts = 10});

  final int maxAttempts;
  int _attempts = 0;
  bool _hasActiveSession = false;

  int get attempts => _attempts;
  bool get hasActiveSession => _hasActiveSession;

  void startSession() {
    _hasActiveSession = true;
    _attempts = 0;
  }

  void endSession() {
    _hasActiveSession = false;
    _attempts = 0;
  }

  /// Feeds a raw connection status transition into the machine and returns
  /// the resulting UI state. Call this every time [SocketService] emits a
  /// new [ConnectionStatus].
  ReconnectUiState onStatusChange(ConnectionStatus status) {
    if (!_hasActiveSession) return ReconnectUiState.idle;

    switch (status) {
      case ConnectionStatus.connected:
        _attempts = 0;
        return ReconnectUiState.stable;
      case ConnectionStatus.connecting:
        return ReconnectUiState.reconnecting;
      case ConnectionStatus.reconnecting:
        _attempts += 1;
        if (_attempts > maxAttempts) return ReconnectUiState.failed;
        return ReconnectUiState.reconnecting;
      case ConnectionStatus.disconnected:
        if (_attempts >= maxAttempts) return ReconnectUiState.failed;
        return ReconnectUiState.reconnecting;
      case ConnectionStatus.unauthorized:
        return ReconnectUiState.sessionExpired;
    }
  }
}
