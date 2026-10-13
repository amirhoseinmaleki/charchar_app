import 'package:flutter/foundation.dart';

class AppImages {
  AppImages._();

  static const coin = 'assets/images/coin.png';

  /// Coin-pack artwork, keyed by the pack's coin amount. Falls back to
  /// [coin] for any amount not listed (e.g. the test pack).
  static const coinPackByAmount = <int, String>{
    1000: 'assets/images/1000.png',
    2000: 'assets/images/2000.png',
    5000: 'assets/images/5000.png',
  };

  static String coinPackImage(int? amount) {
    final hit = coinPackByAmount[amount];
    if (hit != null) return hit;
    if (kDebugMode) {
      debugPrint('[shop] no coin-pack image for coinAmount=$amount '
          '(${amount.runtimeType}) — using default coin.png');
    }
    return coin;
  }

  static const giftBox = 'assets/images/gift-box.png';
  static const back = 'assets/images/back.png';
  static const play = 'assets/images/play.png';
  static const team = 'assets/images/team.png';
  static const rank = 'assets/images/rank.png';
  static const shoppingCart = 'assets/images/shopping-cart.png';
  static const setting = 'assets/images/setting.png';
  static const user = 'assets/images/user.png';
  static const hourglass = 'assets/images/hourglass.png';
  static const warning = 'assets/images/warning.png';
  static const notification = 'assets/images/notification.png';
  static const chat = 'assets/images/chat.png';
  static const logo = 'assets/images/logo.png';
  static const sound = 'assets/images/sound.png';
  static const music = 'assets/images/music.png';
  static const lightBulb = 'assets/images/light-bulb.png';
  static const stopWatch = 'assets/images/stop-watch.png';
}
