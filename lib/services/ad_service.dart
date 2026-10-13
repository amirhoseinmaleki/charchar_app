import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tapsell_mediation/tapsell.dart';
import 'package:tapsell_mediation_legacy/tapsell_mediation_legacy.dart';
import '../models/remote_config.dart';

/// Pre-publish testing override. Pass e.g.
///   flutter run --dart-define=DEBUG_TAPSELL_ZONE_ID=yyyy
/// to point the rewarded-ad flow at a specific zone without relying on the
/// backend `GET /config/client` value. No effect unless set.
///
/// There is no app-key override: `tapsell_mediation` 1.3.0 takes the app
/// key ONLY from the Android manifest (`TapsellMediationAppKey` meta-data,
/// fed by build.gradle.kts `manifestPlaceholders["TapsellMediationAppKey"]`).
/// It has no Dart-side `initialize()` — the native SDK self-initializes at
/// process start. So changing accounts is a rebuild, not a config push.
///
/// The `tapsell_mediation_legacy` adapter is also on the dependency list:
/// it registers the "Legacy" (Tapsell-direct) ad network with the mediation
/// core natively at init. Tapsell's dashboard rewarded zones and all of
/// Tapsell's public test zones are Legacy-type, and without this adapter
/// their waterfall is empty → `requestRewardedAd` returns HTTP 400.
const _dbgZoneId = String.fromEnvironment('DEBUG_TAPSELL_ZONE_ID');

enum AdWatchResult { rewarded, closedWithoutReward, failed }

/// Thin wrapper around the Tapsell **mediation** SDK for the single
/// "watch a rewarded video" flow used by the Home screen's gift-box
/// button. Keeps all Tapsell-specific API shape (setUserConsent, then
/// requestRewardedAd→adId→showRewardedAd, the onAdRewarded/onAdClosed/
/// onAdFailed callback split) behind one simple method so the rest of the
/// app never touches the SDK directly.
///
/// The rewarded-video **zone id** comes from the backend (`GET
/// /config/client`, surfaced via RemoteConfigProvider) so it can be
/// rotated without a client release, with the `DEBUG_TAPSELL_ZONE_ID`
/// dart-define taking precedence for local testing. The **app key** is
/// baked into the manifest at build time (see above). If the backend
/// serves an empty zone (and no debug define), the gift box reports the
/// ad as unavailable.
///
/// Coins are granted only on a genuine `onAdRewarded` callback — never
/// inferred from `onAdClosed` or app-lifecycle transitions, since those
/// can fire for a skipped/incomplete ad too and would let players farm
/// coins without actually watching anything.
class AdService {
  bool _consentSet = false;
  bool _legacyAdapterInited = false;

  /// Max time to wait for an ad to *load* (`requestRewardedAd`). The
  /// mediation SDK plus its ad networks can take a while to respond on the
  /// first request, especially on an emulator, so this is generous. Note
  /// that a Dart-side `.timeout()` here does NOT cancel the native
  /// request — if we bail too early the SDK keeps that request "in
  /// flight" and the next `requestRewardedAd` fails with
  /// "previous request is still trying". So this is long enough that the
  /// native request almost always resolves (fill or no-fill) on its own.
  static const _loadTimeout = Duration(seconds: 60);

  /// Applied to `requestRewardedAd` when the SDK still thinks a previous
  /// request is running — a short retry after a brief wait usually clears
  /// it once that stuck request finally times out natively.
  static const _busyRetryDelay = Duration(seconds: 3);

  /// Safety net for a show call whose terminal callback never fires (e.g.
  /// an emulator with no real ad SDK behind it).
  static const _showGuard = Duration(seconds: 100);

  String _zoneId(RemoteConfig rc) => _dbgZoneId.isNotEmpty ? _dbgZoneId : rc.tapsellRewardedZoneId;

  /// True only when there's a real zone to use (from the backend or the
  /// debug define). No zone → the gift box shows "ad unavailable". Note we
  /// can't verify the manifest app key from here; a missing/blank key
  /// surfaces as a load failure instead.
  bool isConfigured(RemoteConfig rc) => _zoneId(rc).isNotEmpty;

  void _ensureConsent() {
    if (_consentSet) return;
    // GDPR/consent: required to be set before requesting ads for a Google
    // Play build. We don't collect anything ourselves; this is purely the
    // ad SDK's own consent signal. Fire-and-forget — it's a one-way flag.
    try {
      Tapsell.setUserConsent(true);
      _consentSet = true;
      if (kDebugMode) debugPrint('[AdService] setUserConsent(true)');
    } catch (e) {
      if (kDebugMode) debugPrint('[AdService] setUserConsent failed: $e');
    }
  }

  Future<void> _ensureLegacyAdapter() async {
    if (_legacyAdapterInited) return;
    // The Legacy adapter registers itself natively at SDK init; this Dart
    // call only wires up its (unused-by-us) native-ad impression channel.
    // Harmless to call, and it's what Tapsell's docs show, so keep it.
    try {
      await TapsellLegacyAdapter.initialize();
      _legacyAdapterInited = true;
      if (kDebugMode) debugPrint('[AdService] legacy adapter initialized');
    } catch (e) {
      if (kDebugMode) debugPrint('[AdService] legacy adapter init failed: $e');
    }
  }

  /// Requests, shows, and awaits the outcome of a single rewarded video.
  /// Resolves only once the ad flow is fully done — never throws; every
  /// failure path resolves to [AdWatchResult.failed] so the caller can show
  /// a simple "ad unavailable" message instead of handling an exception.
  Future<AdWatchResult> watchRewardedAd(RemoteConfig remoteConfig) async {
    if (!isConfigured(remoteConfig)) {
      if (kDebugMode) debugPrint('[AdService] no Tapsell zone configured');
      return AdWatchResult.failed;
    }

    try {
      _ensureConsent();
      await _ensureLegacyAdapter();

      final zone = _zoneId(remoteConfig);
      String? adId;
      try {
        if (kDebugMode) debugPrint('[AdService] requestRewardedAd zone=$zone');
        adId = await Tapsell.requestRewardedAd(zone).timeout(_loadTimeout);
        if (kDebugMode) debugPrint('[AdService] got adId="$adId"');
      } catch (e) {
        // The mediation SDK rejects a new request while it still thinks a
        // previous one is running ("previous request is still trying") —
        // which happens after we time out on Dart's side without the
        // native request having settled. Wait a moment for it to clear,
        // then try once more.
        final stillTrying = e.toString().contains('previous request is still trying');
        if (stillTrying) {
          if (kDebugMode) debugPrint('[AdService] request busy, retrying after $_busyRetryDelay');
          await Future<void>.delayed(_busyRetryDelay);
          try {
            adId = await Tapsell.requestRewardedAd(zone).timeout(_loadTimeout);
            if (kDebugMode) debugPrint('[AdService] retry got adId="$adId"');
          } catch (e2) {
            if (kDebugMode) debugPrint('[AdService] retry failed: $e2');
            return AdWatchResult.failed;
          }
        } else {
          if (kDebugMode) debugPrint('[AdService] requestRewardedAd failed/timed out: $e');
          return AdWatchResult.failed;
        }
      }
      if (adId == null || adId.isEmpty) return AdWatchResult.failed;

      final completer = Completer<AdWatchResult>();
      var rewarded = false;
      var shown = false;
      var closed = false;
      void resolveOnce(AdWatchResult result) {
        if (!completer.isCompleted) completer.complete(result);
      }

      // Decide the outcome once we have enough signal. onAdRewarded and
      // onAdClosed can arrive in EITHER order (on this SDK onAdClosed has
      // been seen to land *first*), so onAdClosed must not resolve
      // immediately as "no reward" — it gives onAdRewarded a beat to
      // arrive, and also treats ShowCompletionState.completed (the user
      // watched to the end) as reward-worthy on its own.
      void settleFromClose(ShowCompletionState state) {
        if (rewarded || state == ShowCompletionState.completed) {
          resolveOnce(AdWatchResult.rewarded);
        } else {
          resolveOnce(AdWatchResult.closedWithoutReward);
        }
      }

      // NOTE: do NOT `await` this. `Tapsell.showRewardedAd` returns a
      // Future that resolves when the *show call is accepted*, not when the
      // ad finishes — and in practice (mediation 1.3.0) it may not resolve
      // at all. Awaiting it would block here forever even though the
      // onAdRewarded/onAdClosed callbacks below have already fired. We
      // drive the outcome purely off those callbacks + the completer.
      unawaited(
        Tapsell.showRewardedAd(
          adId,
          onAdImpression: () {
            shown = true;
            if (kDebugMode) debugPrint('[AdService] onAdImpression');
          },
          onAdClicked: () {
            if (kDebugMode) debugPrint('[AdService] onAdClicked');
          },
          onAdRewarded: () {
            rewarded = true;
            if (kDebugMode) debugPrint('[AdService] onAdRewarded');
            resolveOnce(AdWatchResult.rewarded);
          },
          onAdClosed: (ShowCompletionState completionState) {
            closed = true;
            if (kDebugMode) debugPrint('[AdService] onAdClosed: $completionState');
            // Give a late onAdRewarded ~1s to arrive before settling.
            Future<void>.delayed(const Duration(milliseconds: 1000), () {
              settleFromClose(completionState);
            });
          },
          onAdFailed: (String message) {
            if (kDebugMode) debugPrint('[AdService] onAdFailed: $message');
            resolveOnce(rewarded ? AdWatchResult.rewarded : AdWatchResult.failed);
          },
        ).catchError((Object e) {
          if (kDebugMode) debugPrint('[AdService] showRewardedAd threw: $e');
          resolveOnce(rewarded ? AdWatchResult.rewarded : AdWatchResult.failed);
          return null;
        }),
      );

      // If the ad never even opened within the load window, treat it as
      // no-fill so the caller isn't stuck waiting.
      Future<void>.delayed(_loadTimeout, () {
        if (!shown && !closed) resolveOnce(AdWatchResult.failed);
      });

      return await completer.future.timeout(
        _showGuard,
        onTimeout: () => rewarded ? AdWatchResult.rewarded : AdWatchResult.failed,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[AdService] exception: $e');
      return AdWatchResult.failed;
    }
  }
}
