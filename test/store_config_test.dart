import 'package:esmvafamilyar/services/iap/store_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StoreConfig', () {
    test('defaults to bazaar when no flavor or dart-define is set', () {
      expect(StoreConfig.active, ActiveStore.bazaar);
      expect(StoreConfig.isBazaar, isTrue);
      expect(StoreConfig.isMyket, isFalse);
    });

    test('ActiveStore IDs match server expectation', () {
      expect(ActiveStore.bazaar.id, 'bazaar');
      expect(ActiveStore.myket.id, 'myket');
    });
  });
}
