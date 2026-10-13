import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:myket_iap/myket_iap.dart';
import 'package:myket_iap/util/iab_result.dart';
import 'package:myket_iap/util/inventory.dart';
import 'package:myket_iap/util/purchase.dart' as myket;

import 'iap_store.dart';

/// [IapStore] backed by Myket in-app billing (`myket_iap`).
///
/// Unlike Poolakey there is no long-lived "connection" to warm up —
/// `MyketIAP` is a set of static methods over a method channel and
/// `MyketIAP.init(rsaKey:)` binds the Myket billing service on first use.
/// [configure] just stashes the key (from `GET /config/client` →
/// `myketRsaPublicKey`); the bind happens lazily on the first store call
/// and is deduped.
///
/// The RSA key here is Myket's, from the Myket developer panel — a
/// *different* key from Bazaar's. The signed payload it produces is the
/// same Play-Billing-style JSON + RSA-SHA1 signature, so the server
/// verifies it exactly like a Bazaar one, just against `MYKET_RSA_PUBLIC_KEY`.
class MyketIapStore implements IapStore {
  MyketIapStore();

  @override
  String get id => 'myket';

  String _rsaKey = '';
  bool _initialized = false;
  Future<bool>? _initializing;

  /// Myket billing response codes we treat as "user backed out", not a
  /// real error (see `myket_iap/util/constants.dart`):
  ///   1     BILLING_RESPONSE_RESULT_USER_CANCELED
  ///   -1005 IABHELPER_USER_CANCELLED
  static const _userCancelledCodes = {1, -1005};

  static const _ipcTimeout = Duration(seconds: 20);

  /// Chain operations to ensure Myket IabHelper never has concurrent async operations
  /// (which triggers "Can't start async operation because another is in progress").
  Future<void> _lastOp = Future<void>.value();

  Future<T> _synchronized<T>(Future<T> Function() action) {
    final prev = _lastOp;
    final completer = Completer<T>();
    _lastOp = completer.future.then<void>((_) {}).catchError((_) {});
    prev.whenComplete(() async {
      try {
        final res = await action();
        completer.complete(res);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  @override
  void configure({required String rsaKey}) {
    if (kDebugMode) {
      debugPrint('[iap:myket] configure rsaKeyLen=${rsaKey.length} '
          '(was ${_rsaKey.length}) platform=${kIsWeb ? "web" : Platform.operatingSystem}');
    }
    if (rsaKey == _rsaKey) {
      if (isSupported && !_initialized) _ensureInitialized();
      return;
    }
    if (_initialized) disconnect(); // old init used a different key
    _rsaKey = rsaKey;
    if (isSupported) _ensureInitialized(); // fire-and-forget, deduped
  }

  @override
  bool get isSupported => !kIsWeb && Platform.isAndroid && _rsaKey.isNotEmpty;

  Future<bool> _ensureInitialized() {
    if (_initialized) return Future.value(true);
    return _initializing ??= _init();
  }

  Future<bool> _init() async {
    try {
      final IabResult? result = await MyketIAP.init(
        rsaKey: _rsaKey,
        enableDebugLogging: kDebugMode,
      ).timeout(_ipcTimeout);
      _initialized = result?.isSuccess() ?? false;
      if (kDebugMode) {
        debugPrint('[iap:myket] init ${_initialized ? 'ok' : 'failed'}: $result');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[iap:myket] init error: $e');
      _initialized = false;
    }
    _initializing = null;
    return _initialized;
  }

  bool _isCancel(IabResult? result) {
    if (result == null) return false;
    return _userCancelledCodes.contains(result.mResponse);
  }

  String _formatMyketError(IabResult? result) {
    if (result == null) return 'پاسخی از مایکت دریافت نشد.';
    final code = result.mResponse;
    final text = switch (code) {
      1 => 'پرداخت توسط کاربر لغو شد.',
      2 => 'خطا در برقراری ارتباط با سرویس مایکت.',
      3 => 'درون‌پرداخت مایکت روی این دستگاه در دسترس نیست.',
      4 => 'این محصول در مایکت در دسترس نیست.',
      5 => 'خطای سیستمی در فراخوانی پرداخت.',
      6 => 'خطا در ثبت سفارش در مایکت (کد ۶). لطفاً بعداً تلاش کنید.',
      7 => 'این بسته قبلاً خریداری شده است.',
      8 => 'محصول خریداری نشده است.',
      _ => result.mMessage.isNotEmpty ? result.mMessage : 'خطای ناشناخته در درون‌پرداخت.',
    };
    return text;
  }

  IapPurchase _toIapPurchase(myket.Purchase p) => IapPurchase(
        purchaseData: p.mOriginalJson,
        dataSignature: p.mSignature,
        purchaseToken: p.mToken,
        productId: p.mSku,
      );

  @override
  Future<IapPurchaseResult> purchase(String sku, {String payload = ''}) async {
    if (!isSupported) return IapPurchaseResult.unavailable();
    if (!await _ensureInitialized()) return IapPurchaseResult.unavailable();

    return _synchronized(() async {
      try {
        final map = await MyketIAP.launchPurchaseFlow(sku: sku, payload: payload);
        final IabResult? result = map[MyketIAP.RESULT] as IabResult?;
        final myket.Purchase? p = map[MyketIAP.PURCHASE] as myket.Purchase?;

        if (result == null || result.isFailure() || p == null) {
          if (_isCancel(result)) return IapPurchaseResult.cancelled();
          final msg = _formatMyketError(result);
          if (kDebugMode) debugPrint('[iap:myket] purchase($sku) failed: $result');
          return IapPurchaseResult.failed(msg);
        }
        // mPurchaseState: 0 = purchased, 1 = canceled/refunded (Play-Billing).
        if (p.mPurchaseState != 0) return IapPurchaseResult.cancelled();
        return IapPurchaseResult.success(_toIapPurchase(p));
      } catch (e) {
        if (kDebugMode) debugPrint('[iap:myket] purchase($sku) error: $e');
        return IapPurchaseResult.failed('خطا در برقراری ارتباط با مایکت.');
      }
    });
  }

  @override
  Future<bool> consume(String purchaseToken) async {
    if (!isSupported || !await _ensureInitialized()) return false;
    return _synchronized(() async {
      try {
        // Myket's consume() takes a Purchase; the SDK only reads its token.
        final stub = myket.Purchase()
          ..mItemType = 'inapp'
          ..mOrderId = ''
          ..mPackageName = ''
          ..mSku = ''
          ..mPurchaseTime = 0
          ..mPurchaseState = 0
          ..mDeveloperPayload = ''
          ..mToken = purchaseToken
          ..mOriginalJson = ''
          ..mSignature = '';
        final map = await MyketIAP.consume(purchase: stub).timeout(_ipcTimeout);
        final IabResult? result = map[MyketIAP.RESULT] as IabResult?;
        return result?.isSuccess() ?? false;
      } catch (e) {
        if (kDebugMode) debugPrint('[iap:myket] consume failed: $e');
        return false;
      }
    });
  }

  @override
  Future<List<IapPurchase>> pendingPurchases() async {
    if (!isSupported || !await _ensureInitialized()) return const [];
    return _synchronized(() async {
      try {
        final map = await MyketIAP.queryInventory(querySkuDetails: false)
            .timeout(_ipcTimeout);
        final IabResult? result = map[MyketIAP.RESULT] as IabResult?;
        final Inventory? inv = map[MyketIAP.INVENTORY] as Inventory?;
        if (result == null || result.isFailure() || inv == null) return const [];
        return [
          for (final p in inv.mPurchaseMap.values)
            if (p.mPurchaseState == 0) _toIapPurchase(p),
        ];
      } catch (e) {
        if (kDebugMode) debugPrint('[iap:myket] queryInventory failed: $e');
        return const [];
      }
    });
  }

  @override
  Future<void> disconnect() async {
    if (!_initialized) return;
    try {
      await MyketIAP.dispose();
    } catch (_) {
      // nothing to do on teardown
    }
    _initialized = false;
  }
}
