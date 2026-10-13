import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'providers/ad_reward_provider.dart';
import 'providers/analytics_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/push_provider.dart';
import 'providers/round_provider.dart';
import 'providers/socket_provider.dart';
import 'providers/sound_provider.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/rtl.dart';

Future<void> main() async {
  // Catch anything that escapes the widget tree or an async gap. In debug
  // we dump it to the console; in release we swallow it silently (no stack
  // trace to a user, no crash-report upload configured). Wire a real
  // crash-reporting SDK in here later if needed.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // The game is designed portrait-only. Lock it here (belt-and-braces
      // with android:screenOrientation="portrait" in the manifest) so an
      // ad SDK's own activity or a tablet can't rotate the UI.
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      FlutterError.onError = (details) {
        if (kDebugMode) {
          FlutterError.dumpErrorToConsole(details);
        }
      };

      try {
        await dotenv.load(fileName: '.env');
      } catch (_) {
        // Missing/unreadable .env — the app falls back to compiled defaults
        // (see dio_client / socket_service). Don't block startup on it.
      }

      // Firebase (Analytics + Cloud Messaging). Must precede any Firebase
      // use. A failure here (e.g. a broken google-services.json) must not
      // block the game from starting — analytics/push just stay dark.
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        if (kDebugMode) debugPrint('Firebase init failed: $e');
      }

      runApp(const ProviderScope(child: EsmVaFamilYarApp()));
    },
    (error, stack) {
      if (kDebugMode) {
        debugPrint('Uncaught zone error: $error\n$stack');
      }
    },
  );
}

class EsmVaFamilYarApp extends ConsumerWidget {
  const EsmVaFamilYarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(unauthorizedSocketWatcherProvider);
    ref.watch(socketAutoConnectProvider);
    ref.watch(socketReconnectResyncProvider);
    // Arm Firebase Analytics user attribution and FCM push (both no-op
    // gracefully if Firebase failed to init or Play Services is absent).
    ref.watch(analyticsUserSyncProvider);
    ref.watch(pushControllerProvider);
    // Build the sound service early so the audio contexts are configured
    // before the first sound, and arm the app-wide background-music
    // controller (plays for the whole logged-in session, every screen).
    ref.watch(soundServiceProvider);
    ref.watch(backgroundMusicControllerProvider);
    // Arm the round controller's socket listeners at app start (it used to
    // be built as a side effect of the old backgroundMusicProvider).
    ref.watch(roundControllerProvider);
    // Keep the global chat subscribed app-wide so the unread badge counts
    // even while the chat screen is closed.
    ref.watch(chatControllerProvider);
    // Keep the gift box controller alive to schedule local notifications when cooldown expires
    ref.watch(giftBoxControllerProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'اسم و فامیل',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // MaterialApp builds its own Directionality from the locale above,
      // but without a matching localization delegate it silently falls
      // back to LTR for the routed content. Forcing it again here, inside
      // `builder` (below MaterialApp's own Directionality in the tree),
      // is what actually makes every screen render RTL.
      builder: (context, child) => ForceRtl(child: child ?? const SizedBox.shrink()),
    );
  }
}
