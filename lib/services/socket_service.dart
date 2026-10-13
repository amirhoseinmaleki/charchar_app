import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

enum ConnectionStatus { connecting, connected, reconnecting, disconnected, unauthorized }

/// Wraps the raw Socket.io client: owns the connection lifecycle, exposes a
/// [ConnectionStatus] stream so UI never silently hangs, and centralizes
/// event emit/listen so screens don't touch socket_io_client directly.
///
/// Every connection requires a session JWT (see AuthService) attached as
/// `auth.token` on the handshake — the backend rejects unauthenticated
/// sockets outright, so [connect] takes the token explicitly rather than
/// letting callers forget to pass it.
class SocketService {
  SocketService({String? serverUrl}) : _serverUrl = serverUrl ?? dotenv.env['SERVER_URL'] ?? 'https://api.woundai.ir';

  final String _serverUrl;
  socket_io.Socket? _socket;

  /// Event handlers registered via [on] before the underlying socket exists
  /// (controllers built at app start, before login triggers [connect]) would
  /// otherwise be silently dropped — `_socket?.on(...)` is a no-op when
  /// `_socket` is null, and nothing re-registers them once the socket comes
  /// up. Keep every handler here and (re)attach the whole set to the socket
  /// in [connect], so listeners survive both a late first connect and any
  /// later reconnect.
  final Map<String, List<void Function(dynamic)>> _handlers = {};

  void _attachHandlers() {
    final socket = _socket;
    if (socket == null) return;
    _handlers.forEach((event, handlers) {
      for (final handler in handlers) {
        socket.off(event, handler);
        socket.on(event, handler);
      }
    });
  }

  final _statusController = StreamController<ConnectionStatus>.broadcast();
  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  ConnectionStatus get status => _status;

  void _setStatus(ConnectionStatus status) {
    _status = status;
    _statusController.add(status);
  }

  bool get isConnected => _socket?.connected ?? false;

  void connect(String token) {
    if (_socket != null) {
      // Re-attach every registered handler before reconnecting. Controllers
      // that called [off]/[on] (or were rebuilt) after the initial connect
      // would otherwise have their listeners missing on the live socket —
      // e.g. the global chat's unread-count listener silently stops firing,
      // so the Home chat badge never updates again.
      _attachHandlers();
      if (!isConnected) {
        _setStatus(ConnectionStatus.reconnecting);
        _socket!.auth = {'token': token};
        _socket!.connect();
      }
      return;
    }

    _setStatus(ConnectionStatus.connecting);

    _socket = socket_io.io(
      _serverUrl,
      socket_io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(double.maxFinite.toInt())
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(8000)
          .setAuth({'token': token})
          .build(),
    );

    _socket!
      ..onConnect((_) {
        // Re-arm app-level listeners on every (re)connect — socket.io's
        // auto-reconnect can bring the transport back with the registered
        // handlers detached, which would leave e.g. the global chat's
        // unread-count listener dead and the Home chat badge frozen.
        _attachHandlers();
        _setStatus(ConnectionStatus.connected);
      })
      ..onDisconnect((_) => _setStatus(ConnectionStatus.disconnected))
      ..onReconnectAttempt((_) => _setStatus(ConnectionStatus.reconnecting))
      ..onReconnect((_) {
        _attachHandlers();
        _setStatus(ConnectionStatus.connected);
      })
      ..onConnectError((err) => _setStatus(_isAuthError(err) ? ConnectionStatus.unauthorized : ConnectionStatus.disconnected))
      ..onError((_) => _setStatus(ConnectionStatus.disconnected));

    // Re-attach any handlers registered before the socket existed (e.g.
    // RoundController / ChatController, built at app start well before
    // login triggers this connect).
    _attachHandlers();

    _socket!.connect();
  }

  bool _isAuthError(dynamic err) {
    final message = err?.toString() ?? '';
    return message.contains('UNAUTHORIZED');
  }

  /// Re-attaches a fresh token (e.g. after login) without recreating the
  /// underlying socket, then reconnects.
  void updateTokenAndReconnect(String token) {
    _socket?.auth = {'token': token};
    _socket?.disconnect();
    _socket?.connect();
  }

  void disconnect() {
    _socket?.disconnect();
  }

  void dispose() {
    _socket?.dispose();
    _statusController.close();
  }

  void emit(String event, [dynamic data]) {
    _socket?.emit(event, data);
  }

  void on(String event, void Function(dynamic data) handler) {
    (_handlers[event] ??= []).add(handler);
    _socket?.on(event, handler);
  }

  void off(String event, [void Function(dynamic data)? handler]) {
    if (handler != null) {
      _handlers[event]?.remove(handler);
    } else {
      _handlers.remove(event);
    }
    _socket?.off(event, handler);
  }

  void once(String event, void Function(dynamic data) handler) {
    _socket?.once(event, handler);
  }
}
