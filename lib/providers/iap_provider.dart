import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/iap/bazaar_iap_store.dart';
import '../services/iap/iap_store.dart';
import '../services/iap/myket_iap_store.dart';
import '../services/iap/store_config.dart';
import 'remote_config_provider.dart';

/// App-wide [IapStore] for the Shop's coin-pack purchases.
///
/// The concrete store is chosen **at build time** by [StoreConfig] (the
/// `STORE` dart-define / Gradle flavor): `bazaar` → [BazaarIapStore],
/// `myket` → [MyketIapStore]. Nothing else in the app knows which market
/// this build targets.
///
/// It watches [remoteConfigProvider] and calls `configure()` whenever this
/// store's RSA key changes — so the billing connection is warmed up as
/// soon as the splash-screen config fetch lands, well before the player
/// taps "buy" in the Shop.
///
///  - `bazaar` reads `bazaarRsaPublicKey`
///  - `myket`  reads `myketRsaPublicKey`
final iapStoreProvider = Provider<IapStore>((ref) {
  final IapStore store =
      StoreConfig.isMyket ? MyketIapStore() : BazaarIapStore();

  ref.listen<String>(
    remoteConfigProvider.select(
      (s) => StoreConfig.isMyket
          ? s.config.myketRsaPublicKey
          : s.config.bazaarRsaPublicKey,
    ),
    (previous, next) => store.configure(rsaKey: next),
    fireImmediately: true,
  );

  ref.onDispose(store.disconnect);
  return store;
});
