import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart' show GameThemeContext;

/// A slow, very low-contrast field of Persian letters drifting upward and
/// gently rotating behind a screen's content — a nod to the word-finding
/// core of "اسم و فامیل". Purely decorative: it ignores pointer events and
/// paints from a single [AnimationController] via [CustomPaint], so it
/// never rebuilds the widget tree.
///
/// Wrap it around (or Stack it behind) a screen body:
/// ```dart
/// Stack(children: [
///   const Positioned.fill(child: FloatingLettersBackground()),
///   realContent,
/// ])
/// ```
class FloatingLettersBackground extends StatefulWidget {
  const FloatingLettersBackground({
    super.key,
    this.color,
    this.letterCount = 28,
    this.opacity = 0.10,
  });

  /// Base color for the glyphs. Defaults to the current theme's
  /// `onSurface`. The per-letter alpha is [opacity] scaled by each
  /// letter's own depth factor, so the field stays subtle.
  final Color? color;

  /// How many glyphs float at once. 14–22 reads well on a phone.
  final int letterCount;

  /// Peak alpha for the nearest (largest) letters. Keep this low — the
  /// field should be barely-there texture, not a pattern that competes
  /// with the UI.
  final double opacity;

  @override
  State<FloatingLettersBackground> createState() =>
      _FloatingLettersBackgroundState();
}

class _FloatingLettersBackgroundState extends State<FloatingLettersBackground>
    with SingleTickerProviderStateMixin {
  // One long, looping clock; each letter maps it to its own phase so the
  // field never visibly "restarts".
  late final AnimationController _controller;
  late final List<_Letter> _letters;

  // Persian alphabet, plus a few final forms that read as distinct shapes.
  static const _glyphs = [
    'ا',
    'ب',
    'پ',
    'ت',
    'ث',
    'ج',
    'چ',
    'ح',
    'خ',
    'د',
    'ذ',
    'ر',
    'ز',
    'ژ',
    'س',
    'ش',
    'ص',
    'ض',
    'ط',
    'ظ',
    'ع',
    'غ',
    'ف',
    'ق',
    'ک',
    'گ',
    'ل',
    'م',
    'ن',
    'و',
    'ه',
    'ی',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();

    final rnd = math.Random(42); // fixed seed → stable layout across rebuilds
    _letters = List.generate(widget.letterCount, (i) {
      return _Letter(
        glyph: _glyphs[rnd.nextInt(_glyphs.length)],
        x: rnd.nextDouble(),
        phase: rnd.nextDouble(),
        // Speed and size correlate: bigger = "closer" = drifts a touch faster.
        depth: 0.35 + rnd.nextDouble() * 0.65,
        drift: (rnd.nextDouble() - 0.5) * 0.06,
        spin: (rnd.nextDouble() - 0.5) * 0.5,
        tilt: (rnd.nextDouble() - 0.5) * 0.5,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.onSurface;
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _LettersPainter(
            progress: _controller,
            letters: _letters,
            color: color,
            peakOpacity: widget.opacity,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Convenience: stacks [child] over a [FloatingLettersBackground] tinted
/// with the theme's hero colour. Use as a screen's `Scaffold.body` so every
/// screen gets the same drifting-letters backdrop with one line.
class LetteredBackdrop extends StatelessWidget {
  const LetteredBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: FloatingLettersBackground(
            color: context.gameTheme.heroGradient.colors.first,
          ),
        ),
        child,
      ],
    );
  }
}

class _Letter {
  _Letter({
    required this.glyph,
    required this.x,
    required this.phase,
    required this.depth,
    required this.drift,
    required this.spin,
    required this.tilt,
  });

  /// The character to draw.
  final String glyph;

  /// Horizontal position, 0..1 of width.
  final double x;

  /// Offset into the shared 0..1 clock so letters aren't in lock-step.
  final double phase;

  /// 0..1 "closeness": scales size, speed and alpha together.
  final double depth;

  /// Small horizontal sway amplitude, in fractions of width.
  final double drift;

  /// Rotations over one full rise (can be negative).
  final double spin;

  /// Static base rotation, radians.
  final double tilt;

  TextPainter? _painter;

  /// A once-laid-out painter for this glyph at its fixed size, drawn at
  /// full [baseColor]; the frame's opacity is layered on at paint time.
  TextPainter painterFor(Color baseColor) {
    return _painter ??= TextPainter(
      text: TextSpan(
        text: glyph,
        style: TextStyle(
          fontFamily: 'Lalezar',
          fontSize: 22.0 + depth * 40.0,
          color: baseColor,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
  }
}

class _LettersPainter extends CustomPainter {
  _LettersPainter({
    required this.progress,
    required this.letters,
    required this.color,
    required this.peakOpacity,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final List<_Letter> letters;
  final Color color;
  final double peakOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;

    for (final l in letters) {
      // Each letter rises from just below the screen to just above it over
      // one loop, cycling on its own phase.
      final p = (t + l.phase) % 1.0;

      final fontSize = 22.0 + l.depth * 40.0;
      final travel = size.height + fontSize * 2;
      final y = size.height + fontSize - p * travel;

      final sway = math.sin((p + l.phase) * math.pi * 2) * l.drift * size.width;
      final x = l.x * size.width + sway;

      // Fade fully in/out over the outer 25% at each end, with a smooth
      // (cosine) ramp rather than a linear one, so a letter never pops in
      // or out as it wraps from the top back to the bottom.
      final edge = (math.min(p, 1 - p) / 0.25).clamp(0.0, 1.0);
      final edgeFade = 0.5 - 0.5 * math.cos(edge * math.pi);
      final alpha = peakOpacity * l.depth * edgeFade;
      if (alpha <= 0.002) continue;

      // One TextPainter per letter, laid out once (glyph + size are fixed);
      // per-frame opacity is applied with a cheap ColorFilter instead of
      // rebuilding the painter every frame.
      final tp = l.painterFor(color);
      final angle = l.tilt + l.spin * p * math.pi * 2;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      canvas.saveLayer(
        Rect.fromCenter(
          center: Offset.zero,
          width: tp.width + 8,
          height: tp.height + 8,
        ),
        Paint()
          ..colorFilter = ColorFilter.mode(
            Colors.white.withValues(alpha: alpha),
            BlendMode.modulate,
          ),
      );
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _LettersPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.peakOpacity != peakOpacity ||
      oldDelegate.letters != letters;
}
