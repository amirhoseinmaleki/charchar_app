import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/auth.dart';
import '../models/game_history.dart';
import 'api_error.dart';
import 'dio_client.dart';

const _tokenStorageKey = 'auth_session_token';

/// Storage-backend options: on Android, force the EncryptedSharedPreferences
/// backend (AES-256 via the Android Keystore) rather than the legacy
/// plaintext-prefs+RSA fallback; on iOS/macOS, keep the item in the
/// Keychain but only readable while the device is unlocked (and never
/// synced to iCloud). `resetOnError` clears a value that can't be decrypted
/// (e.g. after a keystore change on OS upgrade) instead of throwing forever.
const _secureStorageOptions = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true, resetOnError: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
);

/// Handles the phone/OTP login flow against the backend's REST auth
/// endpoints and persists the resulting session JWT in secure storage.
/// SocketService reads the stored token to authenticate the realtime
/// connection — see providers/socket_provider.dart.
class AuthService {
  AuthService({Dio? dio, FlutterSecureStorage? storage, String? baseUrl})
      : _storage = storage ?? _secureStorageOptions,
        _dio = dio ?? buildDio(baseUrl);

  final Dio _dio;
  final FlutterSecureStorage _storage;

  /// Requests an OTP SMS (`POST /auth/request-otp`). Response body is just
  /// `{ "ok": true }` — the code is only delivered by SMS, never echoed.
  Future<void> requestOtp(String phone) async {
    try {
      await _dio.post('/auth/request-otp', data: {'phone': phone});
    } on DioException catch (e) {
      throw _toAuthException(e);
    }
  }

  /// Verifies the OTP. [nickname], when provided for a brand-new account,
  /// is set server-side in the same call so the player lands on Home
  /// already named (no separate nickname step).
  Future<AuthSession> verifyOtp(String phone, String code, {String? nickname}) async {
    try {
      final response = await _dio.post('/auth/verify-otp', data: {
        'phone': phone,
        'code': code,
        if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
      });
      final session = AuthSession.fromJson(response.data as Map<String, dynamic>);
      await _storage.write(key: _tokenStorageKey, value: session.token);
      return session;
    } on DioException catch (e) {
      throw _toAuthException(e);
    }
  }

  /// Sets or changes the nickname. Returns the updated player fields the
  /// server reports back (new balance, changes remaining, amount charged).
  Future<Map<String, dynamic>> setNickname(String token, String nickname) async {
    try {
      final response = await _dio.post(
        '/auth/set-nickname',
        data: {'nickname': nickname},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return (response.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _toAuthException(e);
    }
  }

  /// Fetches the current player's state for a resumed session (app relaunch
  /// with a stored token, no fresh verify-otp response to source it from).
  Future<AuthPlayer> fetchMe(String token) async {
    try {
      final response = await _dio.get(
        '/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return AuthPlayer.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _toAuthException(e);
    }
  }

  /// The player's last 10 games (see GET /auth/me/games), including ones
  /// started but never finished — shown on the Profile screen.
  Future<List<GameHistoryEntry>> fetchRecentGames(String token) async {
    try {
      final response = await _dio.get(
        '/auth/me/games',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final games = (response.data['games'] as List).cast<Map<String, dynamic>>();
      return games.map(GameHistoryEntry.fromJson).toList();
    } on DioException catch (e) {
      throw _toAuthException(e);
    }
  }

  Future<String?> readStoredToken() => _storage.read(key: _tokenStorageKey);

  Future<void> clearSession() => _storage.delete(key: _tokenStorageKey);

  AuthException _toAuthException(DioException e) {
    final err = ApiError.from(e);
    return AuthException(err.code, err.message);
  }
}
