import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router.dart';
import '../services/push_service.dart';
import 'auth_provider.dart';
import 'notification_provider.dart';

final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService();
  ref.onDispose(service.dispose);
  return service;
});

/// Arms FCM once, high in the widget tree (see main.dart). Implements the
/// client side of notifications.md → "Push notifications":
/// - init the SDK + request POST_NOTIFICATIONS,
/// - register the FCM token (`POST /notifications/push-token`) on every
///   start while logged in, after login, and whenever FCM rotates it,
/// - unregister it (`DELETE /notifications/push-token`) on logout,
/// - on a push: refresh the badge; on a tap: mark it read and open
///   /notifications.
///
/// FCM only actually delivers on devices with Google Play Services; the
/// in-app list is the fallback there. Every server call is best-effort.
final pushControllerProvider = Provider<void>((ref) {
  final push = ref.watch(pushServiceProvider);

  String platform() => Platform.isIOS ? 'ios' : 'android';

  Future<void> register(String session) async {
    await push.init();
    final fcm = push.token;
    if (fcm == null) return;
    try {
      await ref.read(notificationServiceProvider).registerPushToken(session, fcm, platform: platform());
      if (kDebugMode) debugPrint('[push] token registered');
    } catch (e) {
      if (kDebugMode) debugPrint('[push] register token failed: $e');
    }
  }

  Future<void> unregister(String session) async {
    final fcm = push.token;
    if (fcm == null) return;
    try {
      await ref.read(notificationServiceProvider).unregisterPushToken(session, fcm);
      if (kDebugMode) debugPrint('[push] token unregistered');
    } catch (e) {
      if (kDebugMode) debugPrint('[push] unregister token failed: $e');
    }
  }

  unawaited(() async {
    await push.init();
    push.scheduleInactivityReminder();
    await push.subscribeToBroadcastTopic();
  }());

  // Splash-time registration for an already-logged-in user, plus every
  // login / account switch / logout afterwards.
  ref.listen<String?>(
    authControllerProvider.select(
      (s) => s.status == AuthStatus.loggedIn ? s.token : null,
    ),
    (previous, next) {
      if (previous == next) return;
      if (previous != null) unawaited(unregister(previous));
      if (next != null) unawaited(register(next));
    },
    fireImmediately: true,
  );

  push.onTokenChanged = (_) {
    final auth = ref.read(authControllerProvider);
    if (auth.status == AuthStatus.loggedIn && auth.token != null) {
      unawaited(register(auth.token!));
    }
  };

  void refreshInbox() {
    ref.invalidate(notificationUnreadCountProvider);
    ref.read(notificationsControllerProvider.notifier).load();
  }

  final fgSub = push.onForegroundMessage.listen((_) => refreshInbox());

  final tapSub = push.onNotificationTap.listen((message) {
    if (kDebugMode) debugPrint('[push] tapped: ${message.data}');
    final id = message.data['notificationId'] as String?;
    if (message.data['type'] == 'notification' && id != null) {
      unawaited(ref.read(notificationsControllerProvider.notifier).markRead(id));
    }
    refreshInbox();
    // Cold start: the router may not have a navigator yet — defer a frame.
    scheduleMicrotask(() => ref.read(routerProvider).push('/notifications'));
  });

  ref.onDispose(() {
    fgSub.cancel();
    tapSub.cancel();
    push.onTokenChanged = null;
  });
});
