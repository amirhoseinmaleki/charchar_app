import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';
import 'auth_provider.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());

/// How often the badge re-checks the server for new broadcasts while the
/// app is open (notifications arrive over REST, not the socket).
const _unreadPollInterval = Duration(seconds: 15);

/// Unread count for the Home notification-bell badge. Re-fetched:
/// - whenever the token changes,
/// - after the notifications screen marks things read (`ref.invalidate`),
/// - and on a [_unreadPollInterval] timer so a broadcast that lands while
///   the app is open shows up without a restart.
/// Cheap `GET /notifications/unread-count`.
final notificationUnreadCountProvider = FutureProvider<int>((ref) async {
  final token = ref.watch(authControllerProvider.select((s) => s.token));
  if (token == null) return 0;

  // Self-invalidating poll.
  final timer = Timer(_unreadPollInterval, () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);

  try {
    return await ref.read(notificationServiceProvider).fetchUnreadCount(token);
  } catch (_) {
    return 0; // badge silently shows nothing on a failed poll
  }
});

class NotificationsState {
  const NotificationsState({
    this.items = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.nextBefore,
    this.error,
  });

  final List<AppNotification> items;
  final int unreadCount;
  final bool isLoading;
  final bool isLoadingMore;

  /// Cursor for the next older page; null once there are no more pages.
  final int? nextBefore;
  final String? error;

  bool get hasMore => nextBefore != null;

  NotificationsState copyWith({
    List<AppNotification>? items,
    int? unreadCount,
    bool? isLoading,
    bool? isLoadingMore,
    int? nextBefore,
    bool clearNextBefore = false,
    String? error,
    bool clearError = false,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      nextBefore: clearNextBefore ? null : (nextBefore ?? this.nextBefore),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class NotificationsController extends StateNotifier<NotificationsState> {
  NotificationsController(this._service, this._ref) : super(const NotificationsState());

  final NotificationService _service;
  final Ref _ref;

  String? get _token => _ref.read(authControllerProvider).token;

  static const _pageSize = 30;

  /// First page (or a pull-to-refresh). Replaces the list.
  Future<void> load() async {
    final token = _token;
    if (token == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await _service.fetchPage(token, limit: _pageSize);
      state = state.copyWith(
        items: page.items,
        unreadCount: page.unreadCount,
        nextBefore: page.nextBefore,
        clearNextBefore: page.nextBefore == null,
        isLoading: false,
      );
      // Keep the Home badge in sync with what this fuller fetch just saw.
      _ref.invalidate(notificationUnreadCountProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Appends the next older page.
  Future<void> loadMore() async {
    final token = _token;
    final before = state.nextBefore;
    if (token == null || before == null || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _service.fetchPage(token, limit: _pageSize, before: before);
      state = state.copyWith(
        items: [...state.items, ...page.items],
        unreadCount: page.unreadCount,
        nextBefore: page.nextBefore,
        clearNextBefore: page.nextBefore == null,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  /// Marks one read — optimistic, then reconciles the count with the server.
  Future<void> markRead(String id) async {
    final token = _token;
    if (token == null) return;
    final target = state.items.where((n) => n.id == id).firstOrNull;
    if (target == null || target.read) return;

    state = state.copyWith(
      items: [
        for (final n in state.items)
          n.id == id ? n.copyWith(read: true, readAt: DateTime.now().millisecondsSinceEpoch) : n,
      ],
      unreadCount: (state.unreadCount - 1).clamp(0, 1 << 31),
    );
    _ref.invalidate(notificationUnreadCountProvider);
    try {
      final unread = await _service.markRead(token, id);
      state = state.copyWith(unreadCount: unread);
    } catch (e) {
      if (kDebugMode) debugPrint('[notif] markRead failed: $e');
    }
  }

  Future<void> markAllRead() async {
    final token = _token;
    if (token == null || state.unreadCount == 0) return;
    state = state.copyWith(
      items: [for (final n in state.items) n.read ? n : n.copyWith(read: true)],
      unreadCount: 0,
    );
    _ref.invalidate(notificationUnreadCountProvider);
    try {
      await _service.markAllRead(token);
    } catch (e) {
      if (kDebugMode) debugPrint('[notif] markAllRead failed: $e');
    }
  }
}

final notificationsControllerProvider =
    StateNotifierProvider<NotificationsController, NotificationsState>((ref) {
  return NotificationsController(ref.watch(notificationServiceProvider), ref);
});
