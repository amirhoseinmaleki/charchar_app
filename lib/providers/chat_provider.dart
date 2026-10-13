import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../services/socket_service.dart';
import 'auth_provider.dart';
import 'socket_provider.dart';

class ChatState {
  const ChatState({
    this.messages = const [],
    this.hasLoadedHistory = false,
    this.lastError,
    this.unreadCount = 0,
  });

  final List<ChatMessage> messages;

  /// True once the first `chat:history` has landed — the screen shows a
  /// spinner until then.
  final bool hasLoadedHistory;

  /// Most recent `chat:error` message (Persian, ready to show), consumed by
  /// the screen via a listener.
  final String? lastError;

  /// New messages since the user last had the chat screen open — drives the
  /// Home chat-icon badge.
  final int unreadCount;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? hasLoadedHistory,
    String? lastError,
    int? unreadCount,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      hasLoadedHistory: hasLoadedHistory ?? this.hasLoadedHistory,
      lastError: clearError ? null : (lastError ?? this.lastError),
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

/// Owns the global chat: subscribes to the socket's `chat:*` events for the
/// whole app session (so the unread badge keeps counting while the chat
/// screen is closed), buffers the retained-window messages, and sends.
class ChatController extends StateNotifier<ChatState> {
  ChatController(this._ref) : super(const ChatState()) {
    final socket = _ref.read(socketServiceProvider);
    socket.on('chat:history', _onHistory);
    socket.on('chat:message', _onMessage);
    socket.on('chat:error', _onError);

    // (Re)request history whenever a connection is (re)established.
    _ref.listen(connectionStatusProvider, (_, next) {
      if (next.valueOrNull == ConnectionStatus.connected) {
        requestHistory();
      }
    });
  }

  final Ref _ref;

  /// True while the chat screen is mounted — new messages don't bump the
  /// unread badge, and are marked seen on close.
  bool _screenOpen = false;

  void _onHistory(dynamic data) {
    final list = ((data as Map)['messages'] as List? ?? const [])
        .map((e) => ChatMessage.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    // History is a full refresh — it doesn't add "new" unread messages.
    state = state.copyWith(messages: list, hasLoadedHistory: true);
  }

  void _onMessage(dynamic data) {
    final msg = ChatMessage.fromJson(((data as Map)['message'] as Map).cast<String, dynamic>());
    // Drop anything that slipped past the retention window client-side.
    final cutoff = DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
    final kept = [
      for (final m in state.messages)
        if (m.createdAt >= cutoff) m,
      msg,
    ];
    final myId = _ref.read(authControllerProvider).player?.id;
    final isOwn = msg.playerId == myId;
    final countsAsUnread = !_screenOpen && !isOwn;
    if (kDebugMode) {
      debugPrint('[chat] message from ${msg.nickname} screenOpen=$_screenOpen '
          'isOwn=$isOwn unread=${countsAsUnread ? state.unreadCount + 1 : state.unreadCount}');
    }
    state = state.copyWith(
      messages: kept,
      unreadCount: _screenOpen ? 0 : state.unreadCount + (countsAsUnread ? 1 : 0),
    );
  }

  void _onError(dynamic data) {
    final message = (data as Map)['message'] as String? ?? 'ارسال پیام ناموفق بود.';
    state = state.copyWith(lastError: message);
  }

  void consumeError() => state = state.copyWith(clearError: true);

  void requestHistory() {
    _ref.read(socketServiceProvider).emit('chat:history');
  }

  void send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _ref.read(socketServiceProvider).emit('chat:send', {'text': trimmed});
  }

  /// Called by the chat screen on mount / dispose. [open] both gates
  /// unread-counting and, when true, clears the current count.
  void setScreenOpen(bool open) {
    _screenOpen = open;
    if (open && state.unreadCount != 0) state = state.copyWith(unreadCount: 0);
  }

  /// Flip only the counting gate, without touching state — safe to call
  /// synchronously from the chat screen's initState (mutating state there
  /// can throw "modified provider during build").
  void markScreenOpen() => _screenOpen = true;
}

final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>((ref) {
  return ChatController(ref);
});

/// Unread count for the Home chat-icon badge.
final chatUnreadCountProvider = Provider<int>((ref) {
  return ref.watch(chatControllerProvider.select((s) => s.unreadCount));
});

/// The signed-in player's id — for aligning own vs others' bubbles.
final myPlayerIdForChatProvider = Provider<String?>((ref) {
  return ref.watch(authControllerProvider.select((s) => s.player?.id));
});
