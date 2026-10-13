import 'package:flutter_test/flutter_test.dart';
import 'package:esmvafamilyar/services/reconnect_state_machine.dart';
import 'package:esmvafamilyar/services/socket_service.dart';

void main() {
  group('ReconnectStateMachine', () {
    test('reports idle when there is no active room session', () {
      final machine = ReconnectStateMachine();
      expect(machine.onStatusChange(ConnectionStatus.disconnected), ReconnectUiState.idle);
    });

    test('reports stable when connected during an active session', () {
      final machine = ReconnectStateMachine()..startSession();
      expect(machine.onStatusChange(ConnectionStatus.connected), ReconnectUiState.stable);
    });

    test('reports reconnecting on disconnect during an active session, not idle', () {
      final machine = ReconnectStateMachine()..startSession();
      machine.onStatusChange(ConnectionStatus.connected);
      expect(machine.onStatusChange(ConnectionStatus.disconnected), ReconnectUiState.reconnecting);
    });

    test('resets attempt count after reconnecting successfully', () {
      final machine = ReconnectStateMachine(maxAttempts: 3)..startSession();
      machine.onStatusChange(ConnectionStatus.reconnecting);
      machine.onStatusChange(ConnectionStatus.reconnecting);
      expect(machine.attempts, 2);
      machine.onStatusChange(ConnectionStatus.connected);
      expect(machine.attempts, 0);
    });

    test('reports failed after exceeding max reconnect attempts', () {
      final machine = ReconnectStateMachine(maxAttempts: 2)..startSession();
      machine.onStatusChange(ConnectionStatus.reconnecting);
      machine.onStatusChange(ConnectionStatus.reconnecting);
      final result = machine.onStatusChange(ConnectionStatus.reconnecting);
      expect(result, ReconnectUiState.failed);
    });

    test('ending the session returns to idle regardless of connection status', () {
      final machine = ReconnectStateMachine()..startSession();
      machine.onStatusChange(ConnectionStatus.reconnecting);
      machine.endSession();
      expect(machine.onStatusChange(ConnectionStatus.disconnected), ReconnectUiState.idle);
    });

    test('starting a new session resets attempts from a prior failed session', () {
      final machine = ReconnectStateMachine(maxAttempts: 1)..startSession();
      machine.onStatusChange(ConnectionStatus.reconnecting);
      expect(machine.onStatusChange(ConnectionStatus.reconnecting), ReconnectUiState.failed);

      machine.startSession();
      expect(machine.attempts, 0);
      expect(machine.onStatusChange(ConnectionStatus.connected), ReconnectUiState.stable);
    });

    test('reports sessionExpired on an unauthorized socket, not a plain reconnect', () {
      final machine = ReconnectStateMachine()..startSession();
      expect(machine.onStatusChange(ConnectionStatus.unauthorized), ReconnectUiState.sessionExpired);
    });

    test('sessionExpired takes priority over retry-count bookkeeping', () {
      final machine = ReconnectStateMachine(maxAttempts: 5)..startSession();
      machine.onStatusChange(ConnectionStatus.reconnecting);
      final result = machine.onStatusChange(ConnectionStatus.unauthorized);
      expect(result, ReconnectUiState.sessionExpired);
      // Attempts counter is irrelevant once the token itself is invalid —
      // retrying more won't help, so it should not be bumped by this status.
      expect(machine.attempts, 1);
    });
  });
}
