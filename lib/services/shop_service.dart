import 'package:dio/dio.dart';
import 'api_error.dart';
import 'dio_client.dart';
import '../models/shop.dart';

/// REST client for `GET /shop/items` and `POST /shop/purchase`. The server
/// is the sole source of truth for prices and ownership — this client never
/// computes or asserts its own balance/ownership state beyond mirroring
/// whatever the server just returned.
class ShopService {
  ShopService({Dio? dio, String? baseUrl})
      : _dio = dio ?? buildDio(baseUrl);

  final Dio _dio;

  Future<ShopCatalog> fetchItems(String token) async {
    try {
      final response = await _dio.get(
        '/shop/items',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return ShopCatalog.fromJson((response.data as Map).cast());
    } on DioException catch (e) {
      throw _toShopException(e);
    }
  }

  /// Buys [itemId]. The server auto-equips the bought cosmetic and returns
  /// the new balance, owned set, and equipped state.
  Future<ShopMutationResult> purchase(String token, String itemId) async {
    try {
      final response = await _dio.post(
        '/shop/purchase',
        data: {'itemId': itemId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return ShopMutationResult.fromJson((response.data as Map).cast());
    } on DioException catch (e) {
      throw _toShopException(e);
    }
  }

  /// Credits a coin pack after a completed store purchase (Cafe Bazaar or
  /// Myket). [purchaseData] and [dataSignature] are passed **verbatim**
  /// from the store SDK — the server verifies the RSA signature over the
  /// raw `purchaseData` bytes, against the key for [store] (`'bazaar'` →
  /// `BAZAAR_RSA_PUBLIC_KEY`, `'myket'` → `MYKET_RSA_PUBLIC_KEY`). Idempotent
  /// on the purchase token: a retry returns `200` again with
  /// `alreadyProcessed: true` and no extra credit.
  ///
  /// NOTE: a build only ever talks to one store (fixed by the `STORE`
  /// dart-define / Gradle flavor), so `store` is constant for a given APK.
  Future<CoinPurchaseResult> purchaseCoins(
    String token, {
    required String purchaseData,
    required String dataSignature,
    required String store,
  }) async {
    try {
      final response = await _dio.post(
        '/shop/purchase/coins',
        data: {
          'purchaseData': purchaseData,
          'dataSignature': dataSignature,
          'store': store,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return CoinPurchaseResult.fromJson((response.data as Map).cast());
    } on DioException catch (e) {
      throw _toShopException(e);
    }
  }

  /// Equips an owned cosmetic for [category] ('avatar' or 'nameColor'), or
  /// unequips it back to the default when [itemId] is null.
  Future<ShopMutationResult> equip(String token, String category, String? itemId) async {
    try {
      final response = await _dio.post(
        '/shop/equip',
        data: {'category': category, 'itemId': itemId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return ShopMutationResult.fromJson((response.data as Map).cast());
    } on DioException catch (e) {
      throw _toShopException(e);
    }
  }

  ShopException _toShopException(DioException e) {
    final err = ApiError.from(e);
    return ShopException(err.code, err.message);
  }
}
