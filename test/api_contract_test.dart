import 'package:flutter_test/flutter_test.dart';
import 'package:esmvafamilyar/models/ad_reward.dart';
import 'package:esmvafamilyar/services/remote_config_service.dart';

void main() {
  group('Esmfamil API Contract & Models', () {
    test('AdRescueStatus parses valid JSON correctly', () {
      final json = {
        'canWatch': true,
        'viewsRemainingToday': 4,
        'maxPerDay': 5,
        'cooldownEndsAt': 1790190000000,
        'coinAmount': 50,
        'eligibleByBalance': true,
        'balanceThreshold': 100,
        'coinBalance': 30,
      };

      final status = AdRescueStatus.fromJson(json);

      expect(status.canWatch, isTrue);
      expect(status.viewsRemainingToday, equals(4));
      expect(status.maxPerDay, equals(5));
      expect(status.coinAmount, equals(50));
      expect(status.eligibleByBalance, isTrue);
      expect(status.balanceThreshold, equals(100));
      expect(status.coinBalance, equals(30));
      expect(status.cooldownEndsAt, isNotNull);
    });

    test('AdRescueStatus handles missing or null fields gracefully', () {
      final status = AdRescueStatus.fromJson({});

      expect(status.canWatch, isFalse);
      expect(status.viewsRemainingToday, equals(0));
      expect(status.maxPerDay, equals(0));
      expect(status.coinAmount, equals(0));
      expect(status.eligibleByBalance, isFalse);
      expect(status.balanceThreshold, equals(100));
      expect(status.coinBalance, equals(0));
      expect(status.cooldownEndsAt, isNull);
    });

    test('ServerHealth parses valid JSON correctly', () {
      final json = {
        'status': 'ok',
        'uptime': 3600.5,
        'timestamp': 1790190000000,
      };

      final health = ServerHealth.fromJson(json);

      expect(health.status, equals('ok'));
      expect(health.uptime, equals(3600.5));
      expect(health.timestamp.millisecondsSinceEpoch, equals(1790190000000));
    });
  });
}
