/// Store-neutral in-app-billing contract for the Shop's coin-pack purchases.
///
/// Two implementations exist, one per Android market:
///  - [BazaarIapStore]  — Cafe Bazaar, via `flutter_poolakey`
///  - [MyketIapStore]    — Myket, via `myket_iap`
///
/// Which one is live is fixed **at build time** by the `STORE` dart-define
/// (`bazaar` | `myket`), wired to the matching Gradle product flavor — see
/// [StoreConfig] and `MYKET_IAP.md`. Callers (the Shop provider) only ever
/// touch [IapStore]; they never import a concrete store or branch on which
/// market this build targets.
///
/// **Android only.** On every other platform, and until [configure] has
/// been given a non-empty RSA key, [isSupported] is `false` and every
/// method returns an inert result — callers never branch on
/// `Platform.isAndroid`.
library;

/// The signed payload from a completed store purchase — exactly the two
/// fields `POST /shop/purchase/coins` verifies, verbatim from the store
/// SDK, plus the ids the caller needs to consume/replay it.
///
/// Both Cafe Bazaar (Poolakey) and Myket mirror Play Billing here: the
/// server checks an RSA-SHA1 signature over the raw [purchaseData] bytes,
/// so that string must never be re-serialized.
class IapPurchase {
  const IapPurchase({
    required this.purchaseData,
    required this.dataSignature,
    required this.purchaseToken,
    required this.productId,
  });

  /// Raw, unmodified JSON string — Poolakey's `PurchaseInfo.originalJson`
  /// or Myket's `Purchase.mOriginalJson`. The server verifies the RSA
  /// signature over *these exact bytes* — never re-serialize it.
  final String purchaseData;

  /// Base64 signature — Poolakey's `PurchaseInfo.dataSignature` or Myket's
  /// `Purchase.mSignature`.
  final String dataSignature;

  /// Idempotency key; also what [IapStore.consume] needs. Poolakey's
  /// `purchaseToken` / Myket's `Purchase.mToken`.
  final String purchaseToken;

  /// The purchased SKU, for logging / matching a catalog entry.
  final String productId;
}

/// Outcome of an [IapStore.purchase] attempt.
class IapPurchaseResult {
  const IapPurchaseResult._({
    this.purchase,
    this.cancelled = false,
    this.unavailable = false,
    this.error,
  });

  /// The signed purchase, present only on success.
  final IapPurchase? purchase;

  /// User dismissed the store dialog — not an error, don't show one.
  final bool cancelled;

  /// Billing isn't usable here (non-Android, store app missing, not
  /// configured, connect failed). Caller should fall back / hide coin packs.
  final bool unavailable;

  /// A real, unexpected failure worth surfacing.
  final Object? error;

  bool get success => purchase != null;

  factory IapPurchaseResult.success(IapPurchase p) =>
      IapPurchaseResult._(purchase: p);
  factory IapPurchaseResult.cancelled() =>
      const IapPurchaseResult._(cancelled: true);
  factory IapPurchaseResult.unavailable() =>
      const IapPurchaseResult._(unavailable: true);
  factory IapPurchaseResult.failed(Object e) => IapPurchaseResult._(error: e);
}

/// The one in-app-billing surface the Shop talks to. See the library doc.
abstract class IapStore {
  /// A short id for the backing market — `'bazaar'` or `'myket'`. Sent to
  /// the server as the `store` field of `POST /shop/purchase/coins` so it
  /// can verify the signature against the right market's RSA key.
  String get id;

  /// Feeds in the RSA key from backend config and warms up the connection.
  /// A changed key drops the current connection so the next call
  /// reconnects with the new one. Safe to call repeatedly (e.g. on every
  /// config refresh) — it dedupes.
  void configure({required String rsaKey});

  /// `true` only on Android, with a non-empty RSA key configured.
  bool get isSupported;

  /// Launches the store's purchase dialog for [sku] (a coin pack's
  /// `bazaarSku`). [payload] is echoed back in the purchase and can carry
  /// the player id for server-side matching.
  Future<IapPurchaseResult> purchase(String sku, {String payload = ''});

  /// Consumes a purchased coin pack so it can be bought again. Call this
  /// **only after** the backend has confirmed the credit (any `200 ok`
  /// from `/shop/purchase/coins`, including `alreadyProcessed: true`).
  Future<bool> consume(String purchaseToken);

  /// Coin-pack purchases the store still has on record for this account
  /// that were never consumed — e.g. the app died between a successful
  /// store purchase and the backend credit. Replay each through
  /// `/shop/purchase/coins` (idempotent), then [consume].
  Future<List<IapPurchase>> pendingPurchases();

  /// Tear down the store connection. Best-effort.
  Future<void> disconnect();
}
