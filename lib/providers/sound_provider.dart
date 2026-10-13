import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sound_service.dart';
import 'auth_provider.dart';

final soundServiceProvider = Provider<SoundService>((ref) {
  final service = SoundService();
  service.init();
  ref.onDispose(service.dispose);
  return service;
});

/// Imperative handle onto the looping background track.
final backgroundMusicProvider = Provider<BackgroundMusic>((ref) {
  return BackgroundMusic(ref.read(soundServiceProvider));
});

class BackgroundMusic {
  BackgroundMusic(this._sound);

  final SoundService _sound;

  void start() => _sound.startBackgroundMusic();
  void stop() => _sound.stopBackgroundMusic();
}

/// Plays the background music **app-wide** for the whole session: it starts
/// once the player is logged in and keeps looping across every screen,
/// pausing only when the app goes to the background (and when sound is
/// turned off in Settings) and resuming on return. Read once near app
/// start — see main.dart — so the listener is always armed, the same way
/// the socket providers are.
final backgroundMusicControllerProvider = Provider<void>((ref) {
  final music = ref.read(backgroundMusicProvider);

  void apply() {
    final shouldPlay = ref.read(soundEnabledProvider) &&
        ref.read(authControllerProvider).status == AuthStatus.loggedIn;
    if (shouldPlay) {
      music.start();
    } else {
      music.stop();
    }
  }

  // Only the LOGIN STATUS and the sound toggle gate the music — not every
  // auth-state emission (coin balance, nickname, reconnect all bump
  // authControllerProvider and must NOT restart/stop the track).
  ref.listen(
    authControllerProvider.select((s) => s.status),
    (_, _) => apply(),
    fireImmediately: true,
  );
  ref.listen(soundEnabledProvider, (_, _) => apply());

  // Pause only when the OS actually backgrounds the app (paused/detached),
  // NOT on `inactive`/`hidden` — those fire for transient overlays,
  // the recents thumbnail, permission dialogs and some nav transitions,
  // and were cutting the music mid-navigation.
  final observer = _MusicLifecycleObserver(
    onPaused: music.stop,
    onResumed: apply,
  );
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
});

class _MusicLifecycleObserver with WidgetsBindingObserver {
  _MusicLifecycleObserver({required this.onPaused, required this.onResumed});

  final VoidCallback onPaused;
  final VoidCallback onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        onResumed();
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        onPaused();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break; // transient — leave the music alone
    }
  }
}

/// Reactive mirror of [SoundService.musicVolume] for the Settings slider.
class MusicVolumeController extends StateNotifier<double> {
  MusicVolumeController(this._sound) : super(_sound.musicVolume) {
    _sound.init().then((_) {
      if (mounted) state = _sound.musicVolume;
    });
  }

  final SoundService _sound;

  Future<void> setVolume(double value) async {
    state = value.clamp(0.0, 1.0);
    await _sound.setMusicVolume(state);
  }
}

final musicVolumeProvider = StateNotifierProvider<MusicVolumeController, double>((ref) {
  return MusicVolumeController(ref.watch(soundServiceProvider));
});

/// Reactive mirror of [SoundService.enabled] for the Settings toggle — the
/// service itself doesn't notify listeners, so this small controller is
/// what lets a switch in the UI actually rebuild when tapped.
class SoundEnabledController extends StateNotifier<bool> {
  SoundEnabledController(this._sound) : super(_sound.enabled) {
    // SoundService.init() (kicked off when soundServiceProvider was built)
    // loads the persisted preference asynchronously — refresh once it's
    // done in case it differs from the synchronous default read above.
    _sound.init().then((_) {
      if (mounted) state = _sound.enabled;
    });
  }

  final SoundService _sound;

  Future<void> setEnabled(bool value) async {
    await _sound.setEnabled(value);
    state = value;
  }
}

final soundEnabledProvider = StateNotifierProvider<SoundEnabledController, bool>((ref) {
  return SoundEnabledController(ref.watch(soundServiceProvider));
});
