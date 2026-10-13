import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

enum AuthStatus { unknown, loggedOut, needsNickname, loggedIn }

class AuthState {
  const AuthState({required this.status, this.token, this.player});

  final AuthStatus status;
  final String? token;
  final AuthPlayer? player;

  AuthState copyWith({AuthStatus? status, String? token, AuthPlayer? player}) {
    return AuthState(
      status: status ?? this.status,
      token: token ?? this.token,
      player: player ?? this.player,
    );
  }

  static const initial = AuthState(status: AuthStatus.unknown);
}

/// Owns the current auth session: restoring a stored token on app start,
/// completing the OTP login flow, and tracking whether the player still
/// needs to set a nickname (first login only).
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._service) : super(AuthState.initial) {
    _restoreSession();
  }

  final AuthService _service;

  static bool _looksLikeJwt(String t) {
    final parts = t.split('.');
    return parts.length == 3 && parts.every((p) => p.isNotEmpty) && t.length < 4096;
  }

  Future<void> _restoreSession() async {
    final token = await _service.readStoredToken();
    // A JWT is three base64url segments joined by dots. Anything that
    // doesn't even look like one (truncated, corrupted, tampered) is
    // discarded up front rather than sent to the server.
    if (token == null || !_looksLikeJwt(token)) {
      if (token != null) await _service.clearSession();
      state = state.copyWith(status: AuthStatus.loggedOut);
      return;
    }

    // Keep the token, but stay in `unknown` (→ router holds on /splash)
    // until GET /auth/me resolves, so the Home screen only ever builds with
    // the real player record — nickname, coin balance, avatar all present,
    // no one-frame placeholders.
    state = state.copyWith(token: token);

    try {
      final player = await _service.fetchMe(token);
      state = state.copyWith(
        status: player.nickname == null ? AuthStatus.needsNickname : AuthStatus.loggedIn,
        player: player,
      );
    } on AuthException catch (e) {
      if (e.code == 'UNAUTHORIZED') {
        await logout();
        return;
      }
      // Server reachable check already gates /splash on GET /config/client,
      // so a failure here is unusual — fall back to an optimistic login so
      // the player isn't stranded; screens show placeholders until a retry.
      state = state.copyWith(status: AuthStatus.loggedIn);
    } catch (_) {
      state = state.copyWith(status: AuthStatus.loggedIn);
    }
  }

  /// Sends the OTP SMS. The code only arrives by SMS.
  Future<void> requestOtp(String phone) => _service.requestOtp(phone);

  /// [nickname] is only meaningful for a first-time signup — passed through
  /// so the server names the new account in the same call.
  Future<AuthSession> verifyOtp(String phone, String code, {String? nickname}) async {
    final session = await _service.verifyOtp(phone, code, nickname: nickname);
    state = AuthState(
      // Still needs the nickname step only if we still have no name after
      // this call (e.g. the signup name was rejected as taken/banned).
      status: session.player.nickname == null ? AuthStatus.needsNickname : AuthStatus.loggedIn,
      token: session.token,
      player: session.player,
    );
    return session;
  }

  /// Sets or changes the nickname. Throws [AuthException] on a server
  /// rejection (locked, taken, not enough coins) so the caller can show it.
  Future<void> setNickname(String nickname) async {
    final token = state.token;
    if (token == null) return;
    final result = await _service.setNickname(token, nickname);

    final currentPlayer = state.player ?? await _service.fetchMe(token);
    state = state.copyWith(
      status: AuthStatus.loggedIn,
      player: currentPlayer.copyWith(
        nickname: result['nickname'] as String? ?? nickname,
        coinBalance: (result['coinBalance'] as num?)?.toInt(),
        nicknameChangesRemaining: (result['nicknameChangesRemaining'] as num?)?.toInt(),
      ),
    );
  }

  Future<void> logout() async {
    await _service.clearSession();
    state = const AuthState(status: AuthStatus.loggedOut);
  }

  /// Applies a fresh coin balance pushed by the server (e.g. after a
  /// createRoom/joinRoom charge or a gameOver refund) without a full
  /// re-fetch. Server is always the source of truth for the actual number.
  void updateCoinBalance(int coinBalance) {
    final player = state.player;
    if (player == null) return;
    state = state.copyWith(player: player.copyWith(coinBalance: coinBalance));
  }

  /// Applies the player's equipped-cosmetics result from a shop
  /// purchase/equip so their avatar and name color update app-wide
  /// immediately. Pass an explicit null [nameColorHex] to clear it.
  void updateAppearance({String? avatarUrl, String? nameColorHex}) {
    final player = state.player;
    if (player == null) return;
    state = state.copyWith(
      player: player.copyWith(
        avatarUrl: avatarUrl ?? player.avatarUrl,
        nameColorHex: nameColorHex,
        clearNameColor: nameColorHex == null,
      ),
    );
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authServiceProvider));
});
