enum ShopCategory { avatar, nameColor, coinPack }

extension ShopCategoryApi on ShopCategory {
  static ShopCategory fromApi(String value) => switch (value) {
        'avatar' => ShopCategory.avatar,
        'nameColor' => ShopCategory.nameColor,
        'coinPack' => ShopCategory.coinPack,
        _ => ShopCategory.avatar,
      };

  String get labelFa => switch (this) {
        ShopCategory.avatar => 'آواتار',
        ShopCategory.nameColor => 'رنگ اسم',
        ShopCategory.coinPack => 'سکه',
      };
}

class ShopItem {
  const ShopItem({
    required this.id,
    required this.category,
    required this.labelFa,
    required this.price,
    required this.owned,
    required this.purchasable,
    this.hex,
    this.bazaarSku,
    this.myketSku,
    this.coinAmount,
  });

  final String id;
  final ShopCategory category;
  final String labelFa;

  /// Cosmetics: the **coin** cost. Coin packs: the **Toman** price, for
  /// display only — the real charge happens in Cafe Bazaar or Myket.
  final int price;
  final bool owned;

  /// Cosmetics: always true. Coin packs: true only when the catalog entry
  /// has both [bazaarSku]/[myketSku] and [coinAmount] > 0; otherwise it's a locked
  /// "به‌زودی" preview.
  final bool purchasable;

  /// For `nameColor` items: the hex the name renders in (`#RRGGBB`). Null
  /// for other categories. Used to draw a real color swatch in the Shop.
  final String? hex;

  /// **coin packs only** — the Cafe Bazaar product id to hand to Poolakey.
  final String? bazaarSku;

  /// **coin packs only** — the Myket product id to hand to MyketIAP.
  final String? myketSku;

  /// **coin packs only** — coins granted on a verified Bazaar purchase.
  final int? coinAmount;

  factory ShopItem.fromJson(Map<String, dynamic> json) {
    return ShopItem(
      id: json['id'] as String,
      category: ShopCategoryApi.fromApi(json['category'] as String),
      labelFa: json['labelFa'] as String,
      price: (json['price'] as num).toInt(),
      owned: json['owned'] as bool? ?? false,
      purchasable: json['purchasable'] as bool? ?? true,
      hex: json['hex'] as String?,
      bazaarSku: json['bazaarSku'] as String?,
      myketSku: json['myketSku'] as String?,
      coinAmount: (json['coinAmount'] as num?)?.toInt(),
    );
  }

  ShopItem copyWith({bool? owned}) {
    return ShopItem(
      id: id,
      category: category,
      labelFa: labelFa,
      price: price,
      owned: owned ?? this.owned,
      purchasable: purchasable,
      hex: hex,
      bazaarSku: bazaarSku,
      myketSku: myketSku,
      coinAmount: coinAmount,
    );
  }
}

class ShopCatalog {
  const ShopCatalog({
    required this.coinBalance,
    required this.items,
    this.equippedAvatarId,
    this.equippedNameColorId,
  });

  final int coinBalance;
  final List<ShopItem> items;
  final String? equippedAvatarId;
  final String? equippedNameColorId;

  factory ShopCatalog.fromJson(Map<String, dynamic> json) {
    return ShopCatalog(
      coinBalance: (json['coinBalance'] as num).toInt(),
      items: (json['items'] as List).map((e) => ShopItem.fromJson((e as Map).cast())).toList(),
      equippedAvatarId: json['equippedAvatarId'] as String?,
      equippedNameColorId: json['equippedNameColorId'] as String?,
    );
  }
}

/// What the server reports back after a purchase or an equip: the fresh
/// balance, the full owned set, and which cosmetics are now equipped (plus
/// their resolved avatar URL / name-color hex, so the rest of the app can
/// update without another round-trip).
class ShopMutationResult {
  const ShopMutationResult({
    required this.coinBalance,
    required this.ownedCosmeticIds,
    required this.equippedAvatarId,
    required this.equippedNameColorId,
    required this.avatarUrl,
    required this.nameColorHex,
  });

  final int? coinBalance;
  final List<String> ownedCosmeticIds;
  final String? equippedAvatarId;
  final String? equippedNameColorId;
  final String? avatarUrl;
  final String? nameColorHex;

  factory ShopMutationResult.fromJson(Map<String, dynamic> json) {
    return ShopMutationResult(
      coinBalance: (json['coinBalance'] as num?)?.toInt(),
      ownedCosmeticIds: ((json['ownedCosmeticIds'] as List?) ?? const []).cast<String>(),
      equippedAvatarId: json['equippedAvatarId'] as String?,
      equippedNameColorId: json['equippedNameColorId'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      nameColorHex: json['nameColorHex'] as String?,
    );
  }
}

/// Result of `POST /shop/purchase/coins` — the server has verified the
/// Cafe Bazaar signature and (idempotently) credited the pack.
class CoinPurchaseResult {
  const CoinPurchaseResult({
    required this.coinBalance,
    required this.coinsGranted,
    required this.alreadyProcessed,
    required this.productId,
  });

  /// Balance AFTER the credit.
  final int coinBalance;

  /// This pack's coinAmount (0 is possible on a replay if the row predates
  /// the field, but normally the pack's real amount).
  final int coinsGranted;

  /// True when this purchaseToken was already credited on an earlier call —
  /// the client should still treat it as success and consume the purchase.
  final bool alreadyProcessed;

  final String productId;

  factory CoinPurchaseResult.fromJson(Map<String, dynamic> json) {
    return CoinPurchaseResult(
      coinBalance: (json['coinBalance'] as num).toInt(),
      coinsGranted: (json['coinsGranted'] as num?)?.toInt() ?? 0,
      alreadyProcessed: json['alreadyProcessed'] as bool? ?? false,
      productId: json['productId'] as String? ?? '',
    );
  }
}

/// Thrown for any known backend shop error (insufficient coins, already
/// owned, item not found). `code` matches the server's error codes.
class ShopException implements Exception {
  const ShopException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'ShopException($code): $message';
}
