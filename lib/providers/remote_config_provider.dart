import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/remote_config.dart';
import '../services/remote_config_service.dart';

final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) => RemoteConfigService());

/// Where the one-time `GET /config/client` fetch stands. The splash screen
/// waits on this before moving the player on, and shows a retry if it fails
/// (a failed fetch means the backend is unreachable — nothing else in the
/// app will work either).
enum RemoteConfigStatus { loading, ready, failed }

class RemoteConfigState {
  const RemoteConfigState({required this.config, required this.status});

  final RemoteConfig config;
  final RemoteConfigStatus status;

  static const initial = RemoteConfigState(config: RemoteConfig.empty, status: RemoteConfigStatus.loading);
}

/// Fetched once at splash-screen startup (see SplashScreen) and cached for
/// the rest of the app session. AdService / IapStore read the current
/// value via `ref.read(remoteConfigProvider).config`.
class RemoteConfigController extends StateNotifier<RemoteConfigState> {
  RemoteConfigController(this._service) : super(RemoteConfigState.initial);

  final RemoteConfigService _service;

  Future<void> load() async {
    state = RemoteConfigState(config: state.config, status: RemoteConfigStatus.loading);
    try {
      final config = await _service.fetch();
      state = RemoteConfigState(config: config, status: RemoteConfigStatus.ready);
    } catch (_) {
      state = RemoteConfigState(config: state.config, status: RemoteConfigStatus.failed);
    }
  }
}

final remoteConfigProvider = StateNotifierProvider<RemoteConfigController, RemoteConfigState>((ref) {
  return RemoteConfigController(ref.watch(remoteConfigServiceProvider));
});

/// Convenience: the config values alone, for readers that don't care about
/// load status (AdService, IapStore, …).
final remoteConfigValueProvider = Provider<RemoteConfig>((ref) {
  return ref.watch(remoteConfigProvider.select((s) => s.config));
});

/// A minimum-splash timer: flips to `true` ~3s after app start so the
/// splash progress bar always plays out even when the real startup work
/// finishes sooner.
final splashMinTimeProvider = StateNotifierProvider<_SplashMinTimer, bool>((ref) {
  return _SplashMinTimer();
});

class _SplashMinTimer extends StateNotifier<bool> {
  _SplashMinTimer() : super(false) {
    Future<void>.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) state = true;
    });
  }
}
