import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shop.dart';
import '../services/iap/store_config.dart';
import '../services/shop_service.dart';
import 'auth_provider.dart';
import 'iap_provider.dart';

final shopServiceProvider = Provider<ShopService>((ref) => ShopService());

/// How a coin-pack (store IAP — Cafe Bazaar or Myket) purchase attempt
/// ended, for the Shop UI to message.
enum CoinPurchaseOutcome {
  /// Coins credited (or already were) — balance is refreshed.
  success,

  /// Player closed the store dialog. Not an error.
  cancelled,

  /// Billing not usable here (non-Android, store app missing, server IAP
  /// disabled). The button should be hidden/locked, but if reached: soft message.
  unavailable,

  /// Store purchase went through but the server rejected the payload
  /// (bad signature, unknown SKU…) or the network failed. The store
  /// purchase is left un-consumed so it can be retried on next open.
  failed,
}

class CoinPurchaseResultStatus {
  const CoinPurchaseResultStatus(this.outcome, [this.errorMessage]);
  final CoinPurchaseOutcome outcome;
  final String? errorMessage;
}

class ShopState {
  const ShopState({
    this.catalog,
    this.isLoading = false,
    this.error,
    this.purchasingItemId,
    this.equippingItemId,
  });

  final ShopCatalog? catalog;
  final bool isLoading;
  final String? error;

  /// Set only for the duration of a single purchase request, so the tapped
  /// item's button (not the whole grid) can show its own loading state.
  final String? purchasingItemId;

  /// Same idea for an equip request in flight.
  final String? equippingItemId;

  ShopState copyWith({
    ShopCatalog? catalog,
    bool? isLoading,
    String? error,
    String? purchasingItemId,
    String? equippingItemId,
    bool clearError = false,
    bool clearPurchasing = false,
    bool clearEquipping = false,
  }) {
    return ShopState(
      catalog: catalog ?? this.catalog,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      purchasingItemId: clearPurchasing ? null : (purchasingItemId ?? this.purchasingItemId),
      equippingItemId: clearEquipping ? null : (equippingItemId ?? this.equippingItemId),
    );
  }

  static const initial = ShopState();
}

class ShopController extends StateNotifier<ShopState> {
  ShopController(this._service, this._ref) : super(ShopState.initial);

  final ShopService _service;
  final Ref _ref;

  /// Fetches the catalog fresh from the server. Pass [reset] true when the
  /// Shop screen (re)opens so a stale catalog isn't shown for a frame
  /// before the new data lands — the screen shows its loading spinner
  /// instead.
  Future<void> load({bool reset = false}) async {
    final token = _ref.read(authControllerProvider).token;
    if (token == null) return;

    state = reset
        ? const ShopState(isLoading: true)
        : state.copyWith(isLoading: true, clearError: true);
    try {
      final catalog = await _service.fetchItems(token);
      state = state.copyWith(catalog: catalog, isLoading: false);
    } on ShopException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  Future<void> purchase(ShopItem item) async {
    final token = _ref.read(authControllerProvider).token;
    if (token == null || state.purchasingItemId != null) return;

    state = state.copyWith(purchasingItemId: item.id, clearError: true);
    try {
      final result = await _service.purchase(token, item.id);
      _applyMutation(result, markOwnedId: item.id);
      state = state.copyWith(clearPurchasing: true);
    } on ShopException catch (e) {
      state = state.copyWith(error: e.message, clearPurchasing: true);
    }
  }

  /// Buys a coin pack through the active store (Cafe Bazaar or Myket, fixed
  /// at build time): open the store dialog → verify + credit server-side
  /// (`/shop/purchase/coins`, told which `store` to verify against) →
  /// consume the store purchase so it can be bought again.
  ///
  /// Order matters: the server credits **before** we consume, so a failure
  /// after the store charge but before the credit leaves an un-consumed
  /// purchase that [restoreCoinPurchases] can replay.
  Future<CoinPurchaseResultStatus> purchaseCoinPack(ShopItem item) async {
    final token = _ref.read(authControllerProvider).token;
    final sku = StoreConfig.isMyket ? (item.myketSku ?? item.bazaarSku) : item.bazaarSku;
    if (token == null || sku == null || sku.isEmpty || state.purchasingItemId != null) {
      return const CoinPurchaseResultStatus(CoinPurchaseOutcome.unavailable);
    }

    final store = _ref.read(iapStoreProvider);
    if (kDebugMode) {
      debugPrint('[iap:${store.id}] purchaseCoinPack sku=$sku isSupported=${store.isSupported}');
    }
    if (!store.isSupported) return const CoinPurchaseResultStatus(CoinPurchaseOutcome.unavailable);

    state = state.copyWith(purchasingItemId: item.id, clearError: true);
    try {
      final payload = _ref.read(authControllerProvider).player?.id ?? '';
      final result = await store.purchase(sku, payload: payload);

      if (result.cancelled) return const CoinPurchaseResultStatus(CoinPurchaseOutcome.cancelled);
      if (result.unavailable) return const CoinPurchaseResultStatus(CoinPurchaseOutcome.unavailable);
      if (!result.success) {
        final errorMsg = result.error?.toString() ?? 'پرداخت انجام نشد.';
        return CoinPurchaseResultStatus(CoinPurchaseOutcome.failed, errorMsg);
      }

      final purchase = result.purchase!;
      try {
        final credit = await _service.purchaseCoins(
          token,
          purchaseData: purchase.purchaseData,
          dataSignature: purchase.dataSignature,
          store: store.id,
        );
        // Any 200 (including alreadyProcessed) → coins delivered, consume.
        await store.consume(purchase.purchaseToken);
        _ref.read(authControllerProvider.notifier).updateCoinBalance(credit.coinBalance);
        final catalog = state.catalog;
        if (catalog != null) {
          state = state.copyWith(
            catalog: ShopCatalog(
              coinBalance: credit.coinBalance,
              items: catalog.items,
              equippedAvatarId: catalog.equippedAvatarId,
              equippedNameColorId: catalog.equippedNameColorId,
            ),
          );
        }
        return const CoinPurchaseResultStatus(CoinPurchaseOutcome.success);
      } on ShopException catch (e) {
        // The store took the money but the server won't credit — leave the
        // purchase un-consumed for a later retry, surface the reason.
        if (kDebugMode) debugPrint('[iap:${store.id}] /shop/purchase/coins rejected: ${e.code}');
        return CoinPurchaseResultStatus(CoinPurchaseOutcome.failed, e.message);
      }
    } finally {
      state = state.copyWith(clearPurchasing: true);
    }
  }

  /// Replays any store coin-pack purchase that was completed but never
  /// credited (app killed mid-flow, earlier network failure). Idempotent —
  /// safe to call on every Shop open. Best-effort, silent.
  Future<void> restoreCoinPurchases() async {
    final token = _ref.read(authControllerProvider).token;
    if (token == null) return;
    final store = _ref.read(iapStoreProvider);
    if (!store.isSupported) return;

    final pending = await store.pendingPurchases();
    for (final p in pending) {
      try {
        final credit = await _service.purchaseCoins(
          token,
          purchaseData: p.purchaseData,
          dataSignature: p.dataSignature,
          store: store.id,
        );
        await store.consume(p.purchaseToken);
        _ref.read(authControllerProvider.notifier).updateCoinBalance(credit.coinBalance);
        final catalog = state.catalog;
        if (catalog != null) {
          state = state.copyWith(
            catalog: ShopCatalog(
              coinBalance: credit.coinBalance,
              items: catalog.items,
              equippedAvatarId: catalog.equippedAvatarId,
              equippedNameColorId: catalog.equippedNameColorId,
            ),
          );
        }
      } on ShopException catch (e) {
        if (kDebugMode) debugPrint('[iap:${store.id}] restore purchase ${p.productId} failed: ${e.code}');
      }
    }
  }

  /// Equips an owned cosmetic. [itemId] null unequips (back to default).
  Future<void> equip(ShopCategory category, String? itemId) async {
    final token = _ref.read(authControllerProvider).token;
    if (token == null || state.equippingItemId != null) return;

    final apiCategory = category == ShopCategory.avatar ? 'avatar' : 'nameColor';
    state = state.copyWith(equippingItemId: itemId ?? '__none_$apiCategory', clearError: true);
    try {
      final result = await _service.equip(token, apiCategory, itemId);
      _applyMutation(result);
      state = state.copyWith(clearEquipping: true);
    } on ShopException catch (e) {
      state = state.copyWith(error: e.message, clearEquipping: true);
    }
  }

  /// Folds a purchase/equip result into shop state and pushes the appearance
  /// change (avatar URL + name color) into the auth controller so every
  /// screen that shows the player updates at once.
  ///
  /// Only rebuilds the `items` list when something in it actually changed
  /// (a purchase flips one item's `owned`); an equip leaves every item
  /// object identical and just swaps the equipped ids, so widgets keyed on
  /// those items are reused rather than torn down and rebuilt.
  void _applyMutation(ShopMutationResult result, {String? markOwnedId}) {
    final catalog = state.catalog;
    if (catalog != null) {
      final ownedIds = result.ownedCosmeticIds.toSet();
      // Which item, if any, needs its `owned` flag flipped to true.
      final newlyOwnedId = markOwnedId ?? (ownedIds.isNotEmpty
          ? catalog.items.firstWhere(
              (i) => ownedIds.contains(i.id) && !i.owned,
              orElse: () => const ShopItem(
                id: '',
                category: ShopCategory.avatar,
                labelFa: '',
                price: 0,
                owned: false,
                purchasable: false,
              ),
            ).id
          : null);

      final items = (newlyOwnedId != null && newlyOwnedId.isNotEmpty)
          ? [for (final i in catalog.items) i.id == newlyOwnedId ? i.copyWith(owned: true) : i]
          : catalog.items; // unchanged reference → no rebuild churn

      state = state.copyWith(
        catalog: ShopCatalog(
          coinBalance: result.coinBalance ?? catalog.coinBalance,
          items: items,
          equippedAvatarId: result.equippedAvatarId,
          equippedNameColorId: result.equippedNameColorId,
        ),
      );
    }

    if (result.coinBalance != null) {
      _ref.read(authControllerProvider.notifier).updateCoinBalance(result.coinBalance!);
    }
    _ref.read(authControllerProvider.notifier).updateAppearance(
          avatarUrl: result.avatarUrl,
          nameColorHex: result.nameColorHex,
        );
  }
}

final shopControllerProvider = StateNotifierProvider<ShopController, ShopState>((ref) {
  return ShopController(ref.watch(shopServiceProvider), ref);
});
