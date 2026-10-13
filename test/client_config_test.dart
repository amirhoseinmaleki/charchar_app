import 'package:flutter_test/flutter_test.dart';
import 'package:esmvafamilyar/models/client_config.dart';
import 'package:esmvafamilyar/models/remote_config.dart';

void main() {
  group('ClientConfig.fromJson', () {
    test('empty object → all compiled fallbacks', () {
      final c = ClientConfig.fromJson(const {});
      expect(c.economy.createRoomCost, Economy.fallback.createRoomCost);
      expect(c.economy.joinRoomCost, Economy.fallback.joinRoomCost);
      expect(c.onlineGame.cost, OnlineGameConfig.fallback.cost);
      expect(c.scoring.pointsUnique, ScoringConfig.fallback.pointsUnique);
      expect(c.timing.roundsPerGame, TimingConfig.fallback.roundsPerGame);
      expect(c.leveling.basePoints, LevelingConfig.fallback.basePoints);
    });

    test('reads valid server values through', () {
      final c = ClientConfig.fromJson(const {
        'economy': {'createRoomCost': 300, 'joinRoomCost': 100},
        'onlineGame': {
          'cost': 100,
          'minPlayers': 3,
          'maxPlayers': 5,
          'prizes': {'first': 150, 'second': 75, 'third': 25},
        },
        'timing': {'roundDurationSeconds': 40, 'roundsPerGame': 5},
        'leveling': {'basePoints': 100, 'maxLevel': 100},
      });
      expect(c.economy.createRoomCost, 300);
      expect(c.economy.joinRoomCost, 100);
      expect(c.onlineGame.prizeFirst, 150);
      expect(c.timing.roundDurationSeconds, 40);
    });

    // --- hostile / malformed input is clamped or ignored, never trusted ---

    test('negative cost is clamped to 0', () {
      final c = ClientConfig.fromJson(const {
        'economy': {'createRoomCost': -999999},
      });
      expect(c.economy.createRoomCost, 0);
    });

    test('absurdly large cost is capped', () {
      final c = ClientConfig.fromJson(const {
        'economy': {'joinRoomCost': 999999999999},
      });
      expect(c.economy.joinRoomCost, lessThanOrEqualTo(10000000));
    });

    test('wrong types fall back instead of throwing', () {
      final c = ClientConfig.fromJson(const {
        'economy': {'createRoomCost': 'not a number', 'joinRoomCost': null},
        'timing': 'garbage',
        'onlineGame': [1, 2, 3],
      });
      expect(c.economy.createRoomCost, Economy.fallback.createRoomCost);
      expect(c.economy.joinRoomCost, Economy.fallback.joinRoomCost);
      expect(c.timing.roundsPerGame, TimingConfig.fallback.roundsPerGame);
      expect(c.onlineGame.cost, OnlineGameConfig.fallback.cost);
    });

    test('numeric string is parsed', () {
      final c = ClientConfig.fromJson(const {
        'economy': {'onlineGameCost': '250'},
      });
      expect(c.economy.onlineGameCost, 250);
    });

    test('round duration is clamped to the documented 10–180 range', () {
      expect(
        ClientConfig.fromJson(const {'timing': {'roundDurationSeconds': 5}})
            .timing.roundDurationSeconds,
        10,
      );
      expect(
        ClientConfig.fromJson(const {'timing': {'roundDurationSeconds': 9999}})
            .timing.roundDurationSeconds,
        180,
      );
    });

    test('onlineGame.maxPlayers can never be below minPlayers', () {
      final c = ClientConfig.fromJson(const {
        'onlineGame': {'minPlayers': 5, 'maxPlayers': 2},
      });
      expect(c.onlineGame.maxPlayers, greaterThanOrEqualTo(c.onlineGame.minPlayers));
    });

    test('leveling.basePoints is never 0 (guards the division)', () {
      final c = ClientConfig.fromJson(const {
        'leveling': {'basePoints': 0},
      });
      expect(c.leveling.basePoints, greaterThanOrEqualTo(1));
      // and levelForScore stays finite / sane
      expect(c.leveling.levelForScore(1000), inInclusiveRange(1, c.leveling.maxLevel));
    });
  });

  group('LevelingConfig.levelForScore matches the server curve', () {
    const lc = LevelingConfig.fallback; // basePoints 100, maxLevel 100

    test('documented thresholds', () {
      expect(lc.levelForScore(0), 1);
      expect(lc.levelForScore(99), 1);
      expect(lc.levelForScore(100), 2); // L2 @ 100
      expect(lc.levelForScore(299), 2);
      expect(lc.levelForScore(300), 3); // L3 @ 300
      expect(lc.levelForScore(1000), 5); // L5 @ 1000
      expect(lc.levelForScore(4500), 10); // L10 @ 4500
    });

    test('clamps to maxLevel and never below 1', () {
      expect(lc.levelForScore(-100), 1);
      expect(lc.levelForScore(1 << 30), lc.maxLevel);
    });

    test('thresholdForLevel is the inverse at boundaries', () {
      for (final l in [1, 2, 3, 5, 10, 25]) {
        final t = lc.thresholdForLevel(l);
        expect(lc.levelForScore(t), l);
        if (t > 0) expect(lc.levelForScore(t - 1), l - 1);
      }
    });
  });

  group('RemoteConfig.fromJson', () {
    test('missing gameplay blocks → keys parsed, config = fallback', () {
      final rc = RemoteConfig.fromJson(const {
        'tapsellAppKey': '  abc  ',
        'tapsellRewardedZoneId': 'zone1',
        'bazaarRsaPublicKey': 'KEY',
        'myketRsaPublicKey': '  MKEY  ',
      });
      expect(rc.tapsellAppKey, 'abc'); // trimmed
      expect(rc.tapsellRewardedZoneId, 'zone1');
      expect(rc.bazaarRsaPublicKey, 'KEY');
      expect(rc.myketRsaPublicKey, 'MKEY'); // trimmed
      expect(rc.config.economy.createRoomCost, Economy.fallback.createRoomCost);
    });

    test('missing myketRsaPublicKey → empty, not an error', () {
      final rc = RemoteConfig.fromJson(const {'bazaarRsaPublicKey': 'KEY'});
      expect(rc.myketRsaPublicKey, '');
    });

    test('absurdly long key string is dropped', () {
      final rc = RemoteConfig.fromJson({
        'bazaarRsaPublicKey': 'x' * 100000,
      });
      expect(rc.bazaarRsaPublicKey, '');
    });

    test('non-string key fields become empty', () {
      final rc = RemoteConfig.fromJson(const {
        'tapsellAppKey': 12345,
        'bazaarRsaPublicKey': ['a'],
      });
      expect(rc.tapsellAppKey, '');
      expect(rc.bazaarRsaPublicKey, '');
    });
  });
}
