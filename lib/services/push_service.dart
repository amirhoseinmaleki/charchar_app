import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../firebase_options.dart';

/// FCM push notifications.
///
/// IMPORTANT: FCM delivery requires Google Play Services on the device. On
/// Play-Services-less phones (a big slice of the Cafe Bazaar market) push
/// will NOT arrive — the in-app `/notifications` REST API (see
/// notifications.md / NotificationService) is the fallback there. This
/// service is best-effort: every call is guarded and failures are logged,
/// never thrown.
///
/// Android 13+ needs the runtime POST_NOTIFICATIONS permission; [init]
/// requests it via [FirebaseMessaging.requestPermission].

/// Must be a top-level function (not a closure / class method) and marked
/// `@pragma('vm:entry-point')` — FCM spins up a separate isolate for it.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Nothing else to do here for now: a "notification"-type message is shown
  // by the OS automatically while the app is backgrounded. Add data-message
  // handling here if the server starts sending data-only pushes.
}

class PushService {
  PushService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _fmOverride = messaging,
        _local = localNotifications ?? FlutterLocalNotificationsPlugin();

  final FirebaseMessaging? _fmOverride;

  /// Resolved lazily: `FirebaseMessaging.instance` throws when
  /// Firebase.initializeApp failed (see main.dart), and that must not take
  /// local notifications down with it.
  FirebaseMessaging get _fm => _fmOverride ?? FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local;

  /// Android channel the foreground helper posts into. Its id must match the
  /// `default_notification_channel_id` meta-data in AndroidManifest.xml so
  /// backgrounded notifications land in the same channel.
  static const _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'اعلان‌های مهم',
    description: 'اعلان‌های بازی اسم و فامیل',
    importance: Importance.high,
  );

  /// Fires when the user taps a notification (from background OR terminated
  /// state) — payload is [RemoteMessage.data]. Wire this to navigation.
  final _tapController = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get onNotificationTap => _tapController.stream;

  /// Fires for every push that lands while the app is in the foreground.
  final _foregroundController = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get onForegroundMessage => _foregroundController.stream;

  /// The current FCM registration token, once [init] has resolved it.
  String? token;

  Future<void>? _initFuture;

  /// Idempotent; every caller (including [scheduleNotification]) awaits the
  /// same run, so nothing touches the plugin before it's initialized.
  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    tz.initializeTimeZones();

    // Foreground-display plumbing (Android). iOS shows foreground
    // notifications itself once setForegroundNotificationPresentationOptions
    // is set, below.
    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (resp) {
        // Tapped a locally-shown notification. A foreground FCM push stashes
        // its notificationId as the payload (see [_showForeground]) — route
        // it through the same tap stream as a backgrounded push.
        final id = resp.payload;
        if (id == null || id.isEmpty) return;
        _tapController.add(RemoteMessage(
          data: {'type': 'notification', 'notificationId': id},
        ));
      },
    );

    // Ask for POST_NOTIFICATIONS (Android 13+) through the local plugin, so
    // local notifications work even where FCM is broken / Play-less.
    if (Platform.isAndroid) {
      try {
        await _local
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } catch (e) {
        if (kDebugMode) debugPrint('[push] local permission request failed: $e');
      }
    }

    try {
      await _initFcm();
    } catch (e) {
      if (kDebugMode) debugPrint('[push] FCM init failed: $e');
    }
  }

  Future<void> _initFcm() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final settings = await _fm.requestPermission();
    if (kDebugMode) {
      debugPrint('[push] permission: ${settings.authorizationStatus}');
    }

    await _fm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // App in foreground: FCM does NOT show the notification, so we do.
    FirebaseMessaging.onMessage.listen((m) {
      _foregroundController.add(m);
      _showForeground(m);
    });

    // App opened from background by tapping the notification.
    FirebaseMessaging.onMessageOpenedApp.listen(_tapController.add);

    // App launched cold from a terminated state by tapping the notification.
    final initial = await _fm.getInitialMessage();
    if (initial != null) _tapController.add(initial);

    try {
      token = await _fm.getToken();
      if (kDebugMode) debugPrint('[push] token: $token');
    } catch (e) {
      if (kDebugMode) debugPrint('[push] getToken failed: $e');
    }

    _fm.onTokenRefresh.listen((t) {
      token = t;
      // pushControllerProvider re-POSTs it to /notifications/push-token.
      onTokenChanged?.call(t);
    });
  }

  /// Set by whoever owns backend registration (a provider) so a refreshed
  /// token can be pushed to the server.
  void Function(String token)? onTokenChanged;

  /// Checks whether a given [time] falls into quiet hours (23:00 to 08:00 AM).
  static bool isQuietHours([DateTime? time]) {
    final t = time ?? DateTime.now();
    // 23:00 at night until 07:59:59 in the morning
    return t.hour >= 23 || t.hour < 8;
  }

  AndroidNotificationDetails get _androidDetails => AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        icon: '@mipmap/ic_launcher',
        importance: Importance.high,
        priority: Priority.high,
      );

  Future<void> _showForeground(RemoteMessage message) async {
    // Ignore notifications received during quiet hours (23:00 to 08:00 AM)
    if (isQuietHours()) {
      if (kDebugMode) debugPrint('[push] Ignored foreground notification during quiet hours (23:00 - 08:00)');
      return;
    }

    final n = message.notification;
    if (n == null) return; // data-only message — nothing to display
    await _local.show(
      id: n.hashCode,
      title: n.title,
      body: n.body,
      payload: message.data['notificationId'] as String?,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  Timer? _inactivityTimer;

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Ignore notifications triggered during quiet hours (23:00 to 08:00 AM)
    if (isQuietHours()) {
      if (kDebugMode) debugPrint('[push] Ignored local notification during quiet hours (23:00 - 08:00)');
      return;
    }

    try {
      await init();
      await _local.show(
        id: id,
        title: title,
        body: body,
        payload: payload,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[push] showLocalNotification failed: $e');
    }
  }

  /// Checks whether a notification with [id] can be scheduled today based on daily limits.
  /// For reward cooldown (ID 7771), limited to max 3 times per day.
  Future<bool> _canScheduleDaily(int id, DateTime scheduledDate) async {
    if (id != 7771) return true; // Only reward cooldown has a 3/day limit
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateKey = '${scheduledDate.year}-${scheduledDate.month}-${scheduledDate.day}';
      final storageKey = 'push_daily_count_${id}_$dateKey';
      final currentCount = prefs.getInt(storageKey) ?? 0;
      if (currentCount >= 3) {
        if (kDebugMode) {
          debugPrint('[push] Ignored schedule notification $id: daily limit of 3 reached for $dateKey');
        }
        return false;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<bool> _isRescheduleOfSame(int id, DateTime scheduledDate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('push_last_scheduled_$id') == scheduledDate.millisecondsSinceEpoch;
    } catch (_) {
      return false;
    }
  }

  Future<void> cancelNotification(int id) async {
    try {
      await init();
      await _local.cancel(id: id);
    } catch (e) {
      if (kDebugMode) debugPrint('[push] cancel $id failed: $e');
    }
  }

  Future<void> _recordScheduledDaily(int id, DateTime scheduledDate) async {
    if (id != 7771) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateKey = '${scheduledDate.year}-${scheduledDate.month}-${scheduledDate.day}';
      final storageKey = 'push_daily_count_${id}_$dateKey';
      // refreshStatus() re-arms the same cooldown on every app open — only a
      // new target time counts toward the 3/day cap.
      final lastKey = 'push_last_scheduled_$id';
      final at = scheduledDate.millisecondsSinceEpoch;
      if (prefs.getInt(lastKey) == at) return;
      await prefs.setInt(lastKey, at);
      final currentCount = prefs.getInt(storageKey) ?? 0;
      await prefs.setInt(storageKey, currentCount + 1);
    } catch (_) {}
  }

  /// Schedules an OS-level notification for a specific future date and time.
  /// If the target time falls into quiet hours (23:00 to 08:00 AM), it is completely ignored/cancelled.
  /// For reward notifications (id=7771), max 3 notifications per day during allowed hours.
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      await init();
      await _local.cancel(id: id);

      // Under no circumstance schedule if it falls between 23:00 and 08:00 AM
      if (isQuietHours(scheduledDate)) {
        if (kDebugMode) {
          debugPrint('[push] Ignored schedule notification $id because $scheduledDate falls into quiet hours (23:00 - 08:00)');
        }
        return;
      }

      // Check daily limit (e.g., max 3 per day for video reward notification)
      final canSchedule = await _isRescheduleOfSame(id, scheduledDate) ||
          await _canScheduleDaily(id, scheduledDate);
      if (!canSchedule) return;

      final tzScheduled = tz.TZDateTime.from(scheduledDate, tz.local);
      if (tzScheduled.isBefore(tz.TZDateTime.now(tz.local))) return;

      Future<void> schedule(AndroidScheduleMode mode) => _local.zonedSchedule(
            id: id,
            title: title,
            body: body,
            scheduledDate: tzScheduled,
            notificationDetails: NotificationDetails(
              android: _androidDetails,
              iOS: const DarwinNotificationDetails(),
            ),
            androidScheduleMode: mode,
            payload: payload,
          );
      try {
        await schedule(AndroidScheduleMode.exactAllowWhileIdle);
      } on PlatformException catch (e) {
        // Exact alarms not permitted (Android 12+ SCHEDULE_EXACT_ALARM
        // revoked / denied) — a few minutes' drift beats no notification.
        if (kDebugMode) debugPrint('[push] exact schedule refused ($e), using inexact');
        await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
      }
      await _recordScheduledDaily(id, scheduledDate);
      if (kDebugMode) {
        debugPrint('[push] scheduled notification $id at $tzScheduled');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[push] scheduleNotification failed: $e');
    }
  }

  /// Schedules a 24-hour inactivity reminder. Resets every time the user opens the app.
  void scheduleInactivityReminder() {
    scheduleNotification(
      id: 7772,
      title: '❤️ دلتنگت شدیم!',
      body: 'یک روزه به اسم و فامیل سر نزدی! بیا یه دور بازی کنیم و امتیاز بگیریم.',
      scheduledDate: DateTime.now().add(const Duration(hours: 24)),
    );
  }

  /// Subscribe to a topic (e.g. broadcast-to-everyone pushes) so the server
  /// can target `/topics/all` without storing every token.
  Future<void> subscribeToBroadcastTopic() async {
    try {
      await _fm.subscribeToTopic('all');
    } catch (e) {
      if (kDebugMode) debugPrint('[push] subscribeToTopic failed: $e');
    }
  }

  void dispose() {
    _inactivityTimer?.cancel();
    _tapController.close();
    _foregroundController.close();
  }
}
