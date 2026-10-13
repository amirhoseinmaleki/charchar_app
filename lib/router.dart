import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/analytics_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/splash_provider.dart';
import 'screens/chat_screen.dart';
import 'screens/create_join_room_screen.dart';
import 'screens/home_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/login_screen.dart';
import 'screens/nickname_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/round_result_screen.dart';
import 'screens/round_screen.dart';
import 'screens/scoreboard_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/shop_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/vote_screen.dart';

/// Bridges the Riverpod state the `redirect` reads (auth session + the
/// one-time remote-config fetch) into a [Listenable] go_router can use —
/// go_router only re-evaluates redirects when this notifies, or on
/// navigation.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
    ref.listen(splashReadyProvider, (_, _) => notifyListeners());
  }
}

/// Shared route observer, available for any screen that needs to react to
/// being covered/revealed by a pushed route via [RouteAware].
final routeObserver = RouteObserver<PageRoute<dynamic>>();

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    // routeObserver: RouteAware screens. analytics observer: logs a
    // `screen_view` to Firebase on every route change.
    observers: [routeObserver, ref.read(analyticsServiceProvider).routeObserver],
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/otp';

      // Hold on /splash until every startup dependency is ready — server
      // reachable (`GET /config/client` ok), session restored, gift-box
      // status attempted, and the ~3s minimum elapsed. A failed config
      // fetch keeps this false and the splash shows a retry.
      if (!ref.read(splashReadyProvider)) {
        return loc == '/splash' ? null : '/splash';
      }

      switch (auth.status) {
        case AuthStatus.unknown:
          return null; // unreachable — handled above
        case AuthStatus.loggedOut:
          return isAuthRoute ? null : '/login';
        case AuthStatus.needsNickname:
          return loc == '/nickname' ? null : '/nickname';
        case AuthStatus.loggedIn:
          return isAuthRoute || loc == '/nickname' || loc == '/splash' ? '/' : null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final extra = state.extra;
          // New callers pass OtpArgs; tolerate a bare phone string too.
          final args = extra is OtpArgs ? extra : OtpArgs(phone: extra as String? ?? '');
          return OtpScreen(phone: args.phone);
        },
      ),
      GoRoute(path: '/nickname', builder: (context, state) => const NicknameScreen()),
      GoRoute(path: '/create-join', builder: (context, state) => const CreateJoinRoomScreen()),
      GoRoute(path: '/leaderboard', builder: (context, state) => const LeaderboardScreen()),
      GoRoute(
        path: '/shop',
        // `extra: {'tab': 'coins'}` (or `?tab=coins`) opens straight on the
        // coin-pack tab — used by the "خرید سکه" button in the
        // insufficient-coins dialog.
        builder: (context, state) {
          final extra = state.extra;
          final tab = (extra is Map && extra['tab'] is String)
              ? extra['tab'] as String
              : state.uri.queryParameters['tab'];
          return ShopScreen(initialTab: tab);
        },
      ),
      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
      GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
      GoRoute(
        path: '/lobby',
        builder: (context, state) => LobbyScreen(roomCode: state.extra as String? ?? ''),
      ),
      GoRoute(
        path: '/round',
        builder: (context, state) => RoundScreen(roomCode: state.extra as String? ?? ''),
      ),
      GoRoute(
        path: '/vote',
        builder: (context, state) => VoteScreen(roomCode: state.extra as String? ?? ''),
      ),
      GoRoute(
        path: '/round-result',
        builder: (context, state) => RoundResultScreen(roomCode: state.extra as String? ?? ''),
      ),
      GoRoute(
        path: '/scoreboard',
        builder: (context, state) => ScoreboardScreen(roomCode: state.extra as String? ?? ''),
      ),
    ],
  );
});
