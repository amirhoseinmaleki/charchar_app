/// Which Android market this build targets — fixed at compile time.
///
/// The value comes from `--dart-define=STORE=bazaar|myket`. Each Gradle
/// product flavor passes its own value automatically (see
/// `android/app/build.gradle.kts`), so the normal build commands are just:
///
/// ```
/// flutter build apk --flavor bazaar
/// flutter build apk --flavor myket
/// ```
///
/// An unknown or missing value falls back to [ActiveStore.bazaar] — the
/// original single-store behaviour.
library;

import 'package:flutter/services.dart' show appFlavor;

enum ActiveStore {
  bazaar,
  myket;

  /// The `store` string sent to `POST /shop/purchase/coins`.
  String get id => name;
}

class StoreConfig {
  const StoreConfig._();

  static const String _raw = String.fromEnvironment('STORE', defaultValue: '');

  static ActiveStore get active {
    // 1. Check Gradle flavor passed to Flutter (e.g. flutter build apk --flavor myket)
    final flavor = appFlavor?.trim().toLowerCase();
    if (flavor == 'myket') return ActiveStore.myket;
    if (flavor == 'bazaar') return ActiveStore.bazaar;

    // 2. Check --dart-define=STORE=myket|bazaar
    final rawTrimmed = _raw.trim().toLowerCase();
    if (rawTrimmed == 'myket') return ActiveStore.myket;

    return ActiveStore.bazaar;
  }

  static bool get isMyket => active == ActiveStore.myket;
  static bool get isBazaar => active == ActiveStore.bazaar;
}
