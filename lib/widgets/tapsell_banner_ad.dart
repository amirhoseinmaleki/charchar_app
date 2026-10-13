import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tapsell_mediation/tapsell.dart';
import '../router.dart';

/// Standard banner zone ID used across the app.
const kDefaultBannerZoneId = '6ab28102da860d2c9f00cf22';

/// Reusable Tapsell standard banner ad widget.
/// Manages request, display, route changes (destroy on pushNext, reload on popNext),
/// and disposal cleanly.
class TapsellBannerAd extends StatefulWidget {
  const TapsellBannerAd({
    super.key,
    this.zoneId = kDefaultBannerZoneId,
    this.bannerPosition = BannerPosition.bottom,
    this.visible = true,
  });

  final String zoneId;
  final BannerPosition bannerPosition;
  final bool visible;

  @override
  State<TapsellBannerAd> createState() => _TapsellBannerAdState();
}

class _TapsellBannerAdState extends State<TapsellBannerAd> with RouteAware {
  String? _adId;
  Timer? _retryTimer;
  bool _isRouteCurrent = true;

  @override
  void initState() {
    super.initState();
    if (widget.visible) {
      _loadAndShowBanner();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final modalRoute = ModalRoute.of(context);
    if (modalRoute is PageRoute) {
      routeObserver.subscribe(this, modalRoute);
    }
  }

  @override
  void didPushNext() {
    // Navigated to another screen on top of this screen
    _isRouteCurrent = false;
    _destroyBanner();
  }

  @override
  void didPopNext() {
    // Returned back to this screen
    _isRouteCurrent = true;
    if (widget.visible) {
      _loadAndShowBanner();
    }
  }

  @override
  void didUpdateWidget(covariant TapsellBannerAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible || oldWidget.zoneId != widget.zoneId) {
      if (!widget.visible) {
        _destroyBanner();
      } else if (_isRouteCurrent) {
        _loadAndShowBanner();
      }
    }
  }

  void _destroyBanner() {
    _retryTimer?.cancel();
    if (_adId != null) {
      Tapsell.destroyBannerAd(_adId!);
      _adId = null;
    }
  }

  Future<void> _loadAndShowBanner() async {
    if (!widget.visible || !_isRouteCurrent) return;
    try {
      Tapsell.setUserConsent(true);
      final adId = await Tapsell.requestBannerAd(
        widget.zoneId,
        bannerSize: BannerSize.banner_320_50,
      );
      if (adId != null &&
          adId.isNotEmpty &&
          mounted &&
          widget.visible &&
          _isRouteCurrent) {
        _adId = adId;
        await Tapsell.showBannerAd(
          adId,
          bannerPosition: widget.bannerPosition,
          onAdImpression: () {
            if (kDebugMode) debugPrint('[TapsellBanner] impression');
          },
          onAdClicked: () {
            if (kDebugMode) debugPrint('[TapsellBanner] clicked');
          },
          onAdFailed: (error) {
            if (kDebugMode) debugPrint('[TapsellBanner] failed: $error');
          },
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[TapsellBanner] error: $e');
      if (mounted && widget.visible && _isRouteCurrent) {
        _retryTimer?.cancel();
        _retryTimer = Timer(const Duration(seconds: 30), () {
          if (mounted && _adId == null && widget.visible && _isRouteCurrent) {
            _loadAndShowBanner();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _destroyBanner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
