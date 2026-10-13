import 'client_config.dart';

/// The `GET /config/client` response — fetched once at app startup instead
/// of bundling any of it in the APK, so a server-side env change takes
/// effect on the next launch with no client release.
///
/// Two kinds of data (see the backend's `client-config.md`):
///  1. **Third-party SDK keys** — [tapsellAppKey] etc. Not secrets in any
///     meaningful sense (the SDKs send them to Tapsell/Bazaar from the
///     device anyway); kept off the APK so they can be rotated server-side.
///     NOTE: the Tapsell app key is ALSO baked into the Android manifest
///     (build.gradle.kts `tapsellAppKey` placeholder) because the mediation
///     SDK reads it from there at startup — the value served here must match.
///  2. **Server-authoritative gameplay numbers** — [config] (coin costs,
///     prizes, scoring, timing, leveling). Advisory, for display only; the
///     server always enforces these itself. Treated as untrusted input and
///     clamped on parse — see [ClientConfig].
class RemoteConfig {
  const RemoteConfig({
    required this.tapsellAppKey,
    required this.tapsellRewardedZoneId,
    required this.bazaarRsaPublicKey,
    required this.myketRsaPublicKey,
    required this.config,
  });

  final String tapsellAppKey;
  final String tapsellRewardedZoneId;

  /// RSA public key for verifying Cafe Bazaar (Poolakey) purchases. Used
  /// only by a `bazaar`-flavored build.
  final String bazaarRsaPublicKey;

  /// RSA public key for verifying Myket purchases. Used only by a
  /// `myket`-flavored build. Absent (empty) until the backend serves it —
  /// see `MYKET_IAP.md`.
  final String myketRsaPublicKey;

  /// Gameplay numbers (economy / onlineGame / scoring / timing / leveling).
  /// Never null — [ClientConfig.fallback] until a fetch succeeds.
  final ClientConfig config;

  factory RemoteConfig.fromJson(Map<String, dynamic> json) {
    return RemoteConfig(
      tapsellAppKey: _str(json['tapsellAppKey']),
      tapsellRewardedZoneId: _str(json['tapsellRewardedZoneId']),
      bazaarRsaPublicKey: _str(json['bazaarRsaPublicKey']),
      myketRsaPublicKey: _str(json['myketRsaPublicKey']),
      config: ClientConfig.fromJson(json),
    );
  }

  /// Trims and length-caps a string field. The RSA key and Tapsell ids are
  /// short; anything absurdly long is a sign of a bad/hostile response and
  /// is dropped rather than stored.
  static String _str(Object? v, {int maxLen = 8192}) {
    if (v is! String) return '';
    final t = v.trim();
    return t.length > maxLen ? '' : t;
  }

  static const empty = RemoteConfig(
    tapsellAppKey: '',
    tapsellRewardedZoneId: '',
    bazaarRsaPublicKey: '',
    myketRsaPublicKey: '',
    config: ClientConfig.fallback,
  );
}
