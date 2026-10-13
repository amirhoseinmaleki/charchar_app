import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A chunky, cartoon-style loading bar: a rounded dark track with a thick
/// outline and a glossy golden fill that fills in uneven, randomised spurts
/// (not a smooth linear sweep).
///
/// The bar crawls to ~[stallAt] over ~[duration] on its own, then **holds
/// there until [ready] turns true** — the last jump to 100% only happens
/// once the real startup work (server reachable + data loaded) is done.
/// If [ready] never comes, the bar never fills.
class CartoonProgressBar extends StatefulWidget {
  const CartoonProgressBar({
    super.key,
    this.ready = false,
    this.duration = const Duration(milliseconds: 3000),
    this.height = 22,
    this.stallAt = 0.9,
  });

  /// When true, the bar animates its final jump from [stallAt] to 1.0.
  final bool ready;

  /// How long the self-driven crawl to [stallAt] takes.
  final Duration duration;
  final double height;

  /// Fill fraction the bar parks at while waiting for [ready].
  final double stallAt;

  @override
  State<CartoonProgressBar> createState() => _CartoonProgressBarState();
}

class _CartoonProgressBarState extends State<CartoonProgressBar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Cumulative fill checkpoints (0..[stallAt]) — the bar jumps between
  /// these, pausing a beat at each, so it feels like "doing chunks of work"
  /// rather than a constant crawl.
  late final List<double> _stops;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    // 4–6 uneven forward jumps up to the stall point.
    final count = 4 + rnd.nextInt(3);
    final raw = List<double>.generate(count, (_) => 0.15 + rnd.nextDouble());
    final total = raw.fold<double>(0, (a, b) => a + b);
    var acc = 0.0;
    _stops = [
      for (final r in raw) (acc += r / total).clamp(0.0, 1.0) * widget.stallAt,
    ];
    _stops[_stops.length - 1] = widget.stallAt;

    _controller = AnimationController(vsync: this, duration: widget.duration)..forward();
    if (widget.ready) _finish();
  }

  @override
  void didUpdateWidget(CartoonProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ready && !oldWidget.ready) _finish();
  }

  void _finish() {
    // Reuse the controller for the final stall→1.0 jump: reset to 0 mapping
    // by switching [_finishing] on and animating a fresh 0→1.
    _finishing = true;
    _finishAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller
      ..duration = const Duration(milliseconds: 450)
      ..forward(from: 0);
  }

  bool _finishing = false;
  Animation<double>? _finishAnim;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Maps the linear controller value to the stepped fill: within each
  /// equal time slice, ease from the previous stop to the next, then hold
  /// briefly before the next slice.
  double _fillFor(double t) {
    if (_finishing) {
      final p = _finishAnim?.value ?? t;
      return widget.stallAt + (1.0 - widget.stallAt) * p.clamp(0.0, 1.0);
    }
    final n = _stops.length;
    final slice = 1 / n;
    final idx = (t / slice).floor().clamp(0, n - 1);
    final localT = ((t - idx * slice) / slice).clamp(0.0, 1.0);
    // Ease the jump over the first 65% of the slice, hold for the rest.
    final eased = Curves.easeOutCubic.transform((localT / 0.65).clamp(0.0, 1.0));
    final from = idx == 0 ? 0.0 : _stops[idx - 1];
    final to = _stops[idx];
    return from + (to - from) * eased;
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFF5C542);
    const goldDeep = Color(0xFFE0A21E);
    const goldLight = Color(0xFFFFE9A8);
    const track = Color(0xFF2A2140);
    const outline = Color(0xFF4A3A6E);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final fill = _fillFor(_controller.value);
        final h = widget.height;
        final radius = h / 2;
        return SizedBox(
          height: h,
          child: Stack(
            children: [
              // Track
              Container(
                decoration: BoxDecoration(
                  color: track,
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: outline, width: 3),
                ),
              ),
              // Fill
              Padding(
                padding: const EdgeInsets.all(3),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: fill.clamp(0.0001, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [goldLight, gold, goldDeep],
                          stops: [0.0, 0.5, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(radius),
                        boxShadow: const [
                          BoxShadow(color: Color(0x66F5C542), blurRadius: 10, spreadRadius: -1),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(radius),
                        // Top gloss highlight
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            margin: const EdgeInsets.only(top: 2, left: 6, right: 6),
                            height: h * 0.32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(radius),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
