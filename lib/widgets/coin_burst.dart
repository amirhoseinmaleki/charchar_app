import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_images.dart';

/// Fires a short burst of coins that arc from [from] to [to] (both in
/// global/overlay coordinates) and fade out on arrival. Self-contained —
/// replaces the abandoned `zo_collection_animation` package, which never
/// actually rendered its overlay entries.
///
/// Call [CoinBurst.fire] once, after a reward is confirmed. It inserts its
/// own [OverlayEntry] into the nearest [Overlay] and removes it when the
/// last coin lands.
class CoinBurst {
  static void fire({
    required BuildContext context,
    required Offset from,
    required Offset to,
    int count = 14,
    double coinSize = 30,
    Duration duration = const Duration(milliseconds: 950),
    Duration stagger = const Duration(milliseconds: 55),
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CoinBurstLayer(
        from: from,
        to: to,
        count: count,
        coinSize: coinSize,
        duration: duration,
        stagger: stagger,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

class _CoinBurstLayer extends StatefulWidget {
  const _CoinBurstLayer({
    required this.from,
    required this.to,
    required this.count,
    required this.coinSize,
    required this.duration,
    required this.stagger,
    required this.onDone,
  });

  final Offset from;
  final Offset to;
  final int count;
  final double coinSize;
  final Duration duration;
  final Duration stagger;
  final VoidCallback onDone;

  @override
  State<_CoinBurstLayer> createState() => _CoinBurstLayerState();
}

class _CoinBurstLayerState extends State<_CoinBurstLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_CoinSpec> _coins;

  // Total run = each coin's own [duration] plus the accumulated launch
  // stagger of the last coin.
  Duration get _total => widget.duration + widget.stagger * (widget.count - 1);

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    _coins = List.generate(widget.count, (i) {
      // Sideways bow of the arc, alternating left/right, plus jitter.
      final dir = i.isEven ? 1.0 : -1.0;
      final bow = dir * (40 + rnd.nextDouble() * 70);
      final launchFrac = (widget.stagger * i).inMilliseconds / _total.inMilliseconds;
      final flightFrac = widget.duration.inMilliseconds / _total.inMilliseconds;
      return _CoinSpec(
        startFraction: launchFrac,
        endFraction: (launchFrac + flightFrac).clamp(0.0, 1.0),
        bow: bow,
        spins: 1 + rnd.nextDouble() * 2,
        startJitter: Offset((rnd.nextDouble() - 0.5) * 26, (rnd.nextDouble() - 0.5) * 26),
        sizeScale: 0.8 + rnd.nextDouble() * 0.5,
      );
    });

    _controller = AnimationController(vsync: this, duration: _total)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Stack(
            children: [
              for (final c in _coins)
                if (t >= c.startFraction && t <= c.endFraction) _buildCoin(c, t),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCoin(_CoinSpec c, double t) {
    // Local 0..1 progress of this individual coin.
    final p = ((t - c.startFraction) / (c.endFraction - c.startFraction)).clamp(0.0, 1.0);
    final eased = Curves.easeInOutCubic.transform(p);

    final start = widget.from + c.startJitter;
    final end = widget.to;

    // Quadratic Bézier with a perpendicular control point for the arc.
    final mid = Offset.lerp(start, end, 0.5)!;
    final axis = end - start;
    final len = axis.distance == 0 ? 1.0 : axis.distance;
    final perp = Offset(-axis.dy / len, axis.dx / len);
    final control = mid + perp * c.bow;

    final pos = _quadBezier(start, control, end, eased);

    // Fade in fast, hold, fade out over the last third.
    final opacity = p < 0.15 ? p / 0.15 : (p > 0.7 ? (1 - (p - 0.7) / 0.3) : 1.0);
    // Shrink slightly as it reaches the balance.
    final scale = (1.0 - 0.35 * eased) * c.sizeScale;

    final size = widget.coinSize;
    return Positioned(
      left: pos.dx - size / 2,
      top: pos.dy - size / 2,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: c.spins * 2 * math.pi * eased,
          child: Transform.scale(
            scale: scale,
            child: Image.asset(AppImages.coin, width: size, height: size),
          ),
        ),
      ),
    );
  }

  Offset _quadBezier(Offset a, Offset b, Offset c, double t) {
    final u = 1 - t;
    return a * (u * u) + b * (2 * u * t) + c * (t * t);
  }
}

class _CoinSpec {
  _CoinSpec({
    required this.startFraction,
    required this.endFraction,
    required this.bow,
    required this.spins,
    required this.startJitter,
    required this.sizeScale,
  });

  final double startFraction;
  final double endFraction;
  final double bow;
  final double spins;
  final Offset startJitter;
  final double sizeScale;
}
