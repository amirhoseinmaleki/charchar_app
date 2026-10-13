import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_poolakey/flutter_poolakey.dart';

import 'iap_store.dart';

/// [IapStore] backed by Cafe Bazaar in-app billing (`flutter_poolakey`).
///
/// The RSA key comes from the backend (`GET /config/client` →
/// `bazaarRsaPublicKey`); [configure] is called with it early (app start)
/// so the Bazaar connection is warm before the first "buy" tap — Bazaar's
/// payment activity needs a settled connection to open.
class BazaarIapStore implements IapStore {
  BazaarIapStore();

  @override
  String get id => 'bazaar';

  String _rsaKey = '';
  bool _connected = false;
  Future<bool>? _connecting;

  @override
  void configure({required String rsaKey}) {
    if (kDebugMode) {
      debugPrint('[iap:bazaar] configure rsaKeyLen=${rsaKey.length} '
          '(was ${_rsaKey.length}) platform=${kIsWeb ? "web" : Platform.operatingSystem}');
    }
    if (rsaKey == _rsaKey) {
      if (isSupported && !_connected) _ensureConnected();
      return;
    }
    if (_connected) disconnect(); // old connection used a different key
    _rsaKey = rsaKey;
    if (isSupported) _ensureConnected(); // fire-and-forget, deduped
  }

  @override
  bool get isSupported => !kIsWeb && Platform.isAndroid && _rsaKey.isNotEmpty;

  /// Cap on Bazaar IPC calls (connect / consume) so a missing or
  /// unresponsive Bazaar app can't hang the UI. The purchase dialog itself
  /// is user-driven and gets its own longer timeout.
  static const _ipcTimeout = Duration(seconds: 6);

  Future<bool> _ensureConnected() {
    if (_connected) return Future.value(true);
    return _connecting ??= _connect();
  }

  Future<bool> _connect() async {
    final completer = Completer<bool>();
    void done(bool ok) {
      if (!completer.isCompleted) completer.complete(ok);
    }

    try {
      await FlutterPoolakey.connect(
        _rsaKey,
        onSucceed: () {
          if (kDebugMode) debugPrint('[iap:bazaar] connectionSucceed');
          _connected = true;
          done(true);
        },
        onFailed: () {
          if (kDebugMode) debugPrint('[iap:bazaar] connectionFailed');
          _connected = false;
          done(false);
        },
        onDisconnected: () {
          if (kDebugMode) debugPrint('[iap:bazaar] disconnected');
          _connected = false;
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[iap:bazaar] connect dispatch error: $e');
      _connecting = null;
      return false;
    }

    final ok = await completer.future.timeout(
      _ipcTimeout,
      onTimeout: () {
        if (kDebugMode) debugPrint('[iap:bazaar] connect timed out (no callback)');
        return false;
      },
    );
    _connecting = null;
    return ok;
  }

  @override
  Future<IapPurchaseResult> purchase(String sku, {String payload = ''}) async {
    if (!isSupported) return IapPurchaseResult.unavailable();
    if (!await _ensureConnected()) return IapPurchaseResult.unavailable();

    try {
      final info = await FlutterPoolakey.purchase(sku, payload: payload);
      if (info.purchaseState != PurchaseState.PURCHASED) {
        // Canceled / refunded state from Bazaar.
        return IapPurchaseResult.cancelled();
      }
      return IapPurchaseResult.success(IapPurchase(
        purchaseData: info.originalJson,
        dataSignature: info.dataSignature,
        purchaseToken: info.purchaseToken,
        productId: info.productId,
      ));
    } catch (e) {
      // Poolakey throws a PlatformException for both a user cancel and a
      // real error; the cancel message contains "cancel".
      final cancelled = e.toString().toLowerCase().contains('cancel');
      if (kDebugMode) {
        debugPrint('[iap:bazaar] purchase($sku) ${cancelled ? 'cancelled' : 'failed'}: $e');
      }
      return cancelled
          ? IapPurchaseResult.cancelled()
          : IapPurchaseResult.failed('خطا در ارتباط با کافه‌بازار.');
    }
  }

  @override
  Future<bool> consume(String purchaseToken) async {
    if (!isSupported || !await _ensureConnected()) return false;
    try {
      return await FlutterPoolakey.consume(purchaseToken).timeout(_ipcTimeout);
    } catch (e) {
      if (kDebugMode) debugPrint('[iap:bazaar] consume failed: $e');
      return false;
    }
  }

  @override
  Future<List<IapPurchase>> pendingPurchases() async {
    if (!isSupported || !await _ensureConnected()) return const [];
    try {
      final list = await FlutterPoolakey.getAllPurchasedProducts().timeout(_ipcTimeout);
      return [
        for (final p in list)
          if (p.purchaseState == PurchaseState.PURCHASED)
            IapPurchase(
              purchaseData: p.originalJson,
              dataSignature: p.dataSignature,
              purchaseToken: p.purchaseToken,
              productId: p.productId,
            ),
      ];
    } catch (e) {
      if (kDebugMode) debugPrint('[iap:bazaar] getAllPurchasedProducts failed: $e');
      return const [];
    }
  }

  @override
  Future<void> disconnect() async {
    if (!_connected) return;
    try {
      await FlutterPoolakey.disconnect();
    } catch (_) {
      // nothing to do on teardown
    }
    _connected = false;
  }
}
