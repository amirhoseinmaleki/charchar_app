import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/persian_numbers.dart';
import './p_text.dart';

/// Circular countdown ring driven by the server's deadline timestamp
/// (epoch ms) rather than a client-only timer, so it can't drift from what
/// the server will actually enforce when the round ends. Ticks locally at
/// ~10fps between rebuilds for smooth animation.
///
/// Cartoon style: a chunky rounded arc with a dark outline on both edges
/// and a soft coloured glow, over a recessed dark track.
class CountdownRing extends StatefulWidget {
  const CountdownRing({
    super.key,
    required this.deadline,
    required this.totalDurationMs,
    required this.child,
    this.onExpired,
    this.onTwelveSecondsLeft,
    this.size = 220,
    this.strokeWidth = 16,
  });

  final DateTime deadline;
  final int totalDurationMs;
  final Widget child;

  /// Called once, the first time the countdown reaches zero — used to
  /// auto-submit at 0:00 per the spec, independent of whether the player
  /// has pressed submit manually.
  final VoidCallback? onExpired;

  /// Called once per countdown, the first tick where 12 seconds or fewer
  /// remain — used to play the "hurry up" timer-warning cue.
  final VoidCallback? onTwelveSecondsLeft;
  final double size;
  final double strokeWidth;

  @override
  State<CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<CountdownRing> {
  Timer? _timer;
  late Duration _remaining;
  bool _hasFiredExpired = false;
  bool _hasFiredTwelveSecondWarning = false;

  @override
  void initState() {
    super.initState();
    // Seed the first frame synchronously (no setState during initState),
    // then let the periodic timer drive the rest.
    _remaining = _remainingNow();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  Duration _remainingNow() {
    final remaining = widget.deadline.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void _tick() {
    if (!mounted) return;
    final clamped = _remainingNow();
    setState(() => _remaining = clamped);
    if (clamped == Duration.zero && !_hasFiredExpired) {
      _hasFiredExpired = true;
      widget.onExpired?.call();
    }
    if (clamped <= const Duration(seconds: 12) && clamped > Duration.zero && !_hasFiredTwelveSecondWarning) {
      _hasFiredTwelveSecondWarning = true;
      widget.onTwelveSecondsLeft?.call();
    }
  }

  @override
  void didUpdateWidget(covariant CountdownRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline) {
      _hasFiredExpired = false;
      _hasFiredTwelveSecondWarning = false;
      _tick();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;
    final fraction = (_remaining.inMilliseconds / widget.totalDurationMs).clamp(0.0, 1.0);
    final secondsLeft = (_remaining.inMilliseconds / 1000).ceil();

    final Color color;
    if (fraction > 0.5) {
      color = gameTheme.successColor;
    } else if (fraction > 0.2) {
      color = Colors.amber;
    } else {
      color = gameTheme.invalidColor;
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CustomPaint(
              painter: _CartoonRingPainter(
                fraction: fraction,
                color: color,
                strokeWidth: widget.strokeWidth,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              widget.child,
              const SizedBox(height: 4),
              _CartoonTimeLabel(text: '${secondsLeft.toPersianString()} ثانیه', color: color),
            ],
          ),
        ],
      ),
    );
  }
}

class _CartoonTimeLabel extends StatelessWidget {
  const _CartoonTimeLabel({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 2),
      ),
      child: PText(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );
  }
}

class _CartoonRingPainter extends CustomPainter {
  _CartoonRingPainter({
    required this.fraction,
    required this.color,
    required this.strokeWidth,
  });

  final double fraction;
  final Color color;
  final double strokeWidth;

  static const _outline = Color(0xFF2A2140);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2 - 3;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = -math.pi / 2;
    final sweep = 2 * math.pi * fraction;

    // Recessed dark track (full circle) with its own thin outline.
    final trackOutline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 6
      ..color = _outline;
    canvas.drawCircle(center, radius, trackOutline);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFF201A30);
    canvas.drawCircle(center, radius, track);

    if (fraction <= 0) return;

    // Glow behind the progress arc.
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawArc(rect, start, sweep, false, glow);

    // Dark outline around the progress arc (drawn slightly thicker under it).
    final arcOutline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 6
      ..strokeCap = StrokeCap.round
      ..color = _outline;
    canvas.drawArc(rect, start, sweep, false, arcOutline);

    // The glossy progress arc: a vertical light→base→deep gradient.
    final light = Color.lerp(color, Colors.white, 0.5)!;
    final deep = Color.lerp(color, Colors.black, 0.25)!;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [light, color, deep],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawArc(rect, start, sweep, false, arc);

    // A small highlight blob near the leading tip.
    final tipAngle = start + sweep;
    final tip = Offset(
      center.dx + radius * math.cos(tipAngle),
      center.dy + radius * math.sin(tipAngle),
    );
    final tipHi = Paint()..color = Colors.white.withValues(alpha: 0.7);
    canvas.drawCircle(tip.translate(-strokeWidth * 0.12, -strokeWidth * 0.12),
        strokeWidth * 0.16, tipHi);
  }

  @override
  bool shouldRepaint(_CartoonRingPainter old) =>
      old.fraction != fraction || old.color != color || old.strokeWidth != strokeWidth;
}
