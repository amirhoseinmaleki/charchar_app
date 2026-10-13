import 'package:flutter/foundation.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:just_audio/just_audio.dart' as ja;
import 'package:shared_preferences/shared_preferences.dart';

void _mlog(String msg) {
  if (kDebugMode) debugPrint('[music] $msg');
}

const _soundEnabledPrefKey = 'sound_enabled';
const _musicVolumePrefKey = 'music_volume';

/// Centralizes every sound effect and the looping background music.
///
/// - **Effects** (button clicks, cues) use a small pool of `audioplayers`
///   [ap.AudioPlayer]s so they can overlap without cutting each other off.
/// - **Background music** uses `just_audio` (ExoPlayer on Android) with
///   `setLoopMode(LoopMode.one)` for reliable, gapless single-track looping.
///
/// **Why the music kept stopping:** `just_audio` defaults to
/// `handleInterruptions: true`, which subscribes to the audio session's
/// interruption + becoming-noisy streams and calls `pause()` on the music
/// whenever *another* audio stream in the app (our own click sounds!) or
/// the OS grabs focus — and it does not reliably auto-resume. We turn that
/// off, configure a shared session that just mixes with others, and drive
/// pause/resume ourselves from app lifecycle only.
class SoundService {
  SoundService();

  static const _clickSound = 'sound/button_click.mp3';
  static const _gameStartSound = 'sound/game-start.mp3';
  static const _timerWarningSound = 'sound/timer_12_second.mp3';
  static const _winnerSound = 'sound/winner.mp3';
  static const _coinCollectSound = 'sound/yodguard-coin-collect-3-540190.mp3';

  /// just_audio asset paths are relative to the project root (pubspec key),
  /// unlike audioplayers' AssetSource which is relative to `assets/`.
  static const _musicAsset = 'assets/sound/music.mp3';

  // handleInterruptions:false — do NOT let the session pause the music when
  // an effect or notification sound plays. androidApplyAudioAttributes /
  // handleAudioSessionActivation off for the same reason.
  final ja.AudioPlayer _musicPlayer = ja.AudioPlayer(
    handleInterruptions: false,
    androidApplyAudioAttributes: false,
    handleAudioSessionActivation: false,
  );

  final List<ap.AudioPlayer> _effectPool =
      List.generate(3, (_) => ap.AudioPlayer());
  int _nextEffectPlayer = 0;

  bool _enabled = true;
  bool get enabled => _enabled;

  bool _effectContextSet = false;
  bool _sessionConfigured = false;
  bool _musicLoaded = false;
  bool _initialised = false;

  /// Background-music volume, 0.0–1.0. Persisted; applied live.
  double _musicVolume = 0.6;
  double get musicVolume => _musicVolume;

  /// What the app wants: true between [startBackgroundMusic] and
  /// [stopBackgroundMusic].
  bool _wantMusic = false;

  // Effects request no audio focus at all so they never interrupt the music.
  static final _noFocusContext = ap.AudioContext(
    android: const ap.AudioContextAndroid(
      audioFocus: ap.AndroidAudioFocus.none,
      contentType: ap.AndroidContentType.sonification,
      usageType: ap.AndroidUsageType.assistanceSonification,
      stayAwake: false,
    ),
    iOS: ap.AudioContextIOS(
      category: ap.AVAudioSessionCategory.ambient,
      options: const {ap.AVAudioSessionOptions.mixWithOthers},
    ),
  );

  Future<void> _configureSession() async {
    if (_sessionConfigured) return;
    _sessionConfigured = true;
    try {
      final session = await AudioSession.instance;
      // A "mix with everything, ask for no focus" configuration: nothing in
      // or out of the app can cause a focus-loss that pauses our music.
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.ambient,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
    } catch (e) {
      _mlog('session configure failed: $e');
    }
  }

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    await _configureSession();

    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_soundEnabledPrefKey) ?? true;
    _musicVolume = (prefs.getDouble(_musicVolumePrefKey) ?? 0.6).clamp(0.0, 1.0);

    if (!_effectContextSet) {
      _effectContextSet = true;
      for (final player in _effectPool) {
        try {
          await player.setAudioContext(_noFocusContext);
        } catch (_) {/* non-fatal */}
      }
    }

    try {
      await _musicPlayer.setLoopMode(ja.LoopMode.one);
      await _musicPlayer.setVolume(_musicVolume);
    } catch (_) {/* non-fatal */}

    if (kDebugMode) {
      _musicPlayer.playerStateStream.listen((s) {
        _mlog('state -> playing=${s.playing} processing=${s.processingState}');
      });
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledPrefKey, value);
    if (!value) {
      await stopBackgroundMusic();
    } else if (_wantMusic) {
      await startBackgroundMusic();
    }
  }

  /// Set the background-music volume (0.0–1.0). Applied immediately and
  /// persisted. Leaves the track running so a bump back up resumes at the
  /// new level — use [setEnabled] to actually stop audio.
  Future<void> setMusicVolume(double value) async {
    _musicVolume = value.clamp(0.0, 1.0);
    try {
      await _musicPlayer.setVolume(_musicVolume);
    } catch (_) {/* no-op */}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_musicVolumePrefKey, _musicVolume);
  }

  Future<void> _playEffect(String asset) async {
    if (!_enabled) return;
    final player = _effectPool[_nextEffectPlayer];
    _nextEffectPlayer = (_nextEffectPlayer + 1) % _effectPool.length;
    try {
      await player.stop();
      await player.play(ap.AssetSource(asset));
    } catch (_) {
      // Sound is a nice-to-have — never surface a playback failure.
    }
  }

  Future<void> playButtonClick() => _playEffect(_clickSound);
  Future<void> playGameStart() => _playEffect(_gameStartSound);
  Future<void> playTimerWarning() => _playEffect(_timerWarningSound);
  Future<void> playWinner() => _playEffect(_winnerSound);

  /// One-shot coin-collect chime (Shop coin-pack purchase, alongside the
  /// coin-fly animation). Not looped — [_playEffect] plays once and stops.
  Future<void> playCoinCollect() => _playEffect(_coinCollectSound);

  Future<void> startBackgroundMusic() async {
    if (!_enabled) return;
    _wantMusic = true;
    try {
      await _configureSession();
      if (!_musicLoaded) {
        await _musicPlayer.setAsset(_musicAsset);
        await _musicPlayer.setLoopMode(ja.LoopMode.one);
        _musicLoaded = true;
      }
      await _musicPlayer.setVolume(_musicVolume);
      if (!_musicPlayer.playing) {
        if (_musicPlayer.processingState == ja.ProcessingState.completed) {
          await _musicPlayer.seek(Duration.zero);
        }
        await _musicPlayer.play();
      }
    } catch (e) {
      _mlog('start error: $e');
    }
  }

  Future<void> stopBackgroundMusic() async {
    _wantMusic = false;
    try {
      await _musicPlayer.pause();
      await _musicPlayer.seek(Duration.zero);
    } catch (_) {/* no-op */}
  }

  Future<void> dispose() async {
    await _musicPlayer.dispose();
    for (final player in _effectPool) {
      await player.dispose();
    }
  }
}
