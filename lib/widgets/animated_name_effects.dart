import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Sentinel values the server sends in `nameColorHex` instead of a
/// `#RRGGBB`, for animated name-color cosmetics.
const kRainbowNameColor = 'rainbow';
const kGlitchNameColor = 'glitch';

bool isRainbowNameColor(String? hex) => hex?.trim().toLowerCase() == kRainbowNameColor;
bool isGlitchNameColor(String? hex) => hex?.trim().toLowerCase() == kGlitchNameColor;

/// True for any animated (non-flat-colour) name effect.
bool isAnimatedNameColor(String? hex) => isRainbowNameColor(hex) || isGlitchNameColor(hex);

const _rainbowColors = [
  Color(0xFFFF3B30),
  Color(0xFFFF9500),
  Color(0xFFFFCC00),
  Color(0xFF34C759),
  Color(0xFF32ADE6),
  Color(0xFF5856D6),
  Color(0xFFAF52DE),
  Color(0xFFFF3B30),
];

/// Renders the animated name effect for [hex] over [child] (the plain
/// [Text]). Callers should only use this when [isAnimatedNameColor] is true.
class AnimatedNameEffect extends StatelessWidget {
  const AnimatedNameEffect({super.key, required this.hex, required this.child});

  final String? hex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (isGlitchNameColor(hex)) return _GlitchText(child: child);
    return _RainbowText(child: child); // default: rainbow
  }
}

class _RainbowText extends StatefulWidget {
  const _RainbowText({required this.child});

  final Widget child;

  @override
  State<_RainbowText> createState() => _RainbowTextState();
}

class _RainbowTextState extends State<_RainbowText> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => LinearGradient(
          colors: _rainbowColors,
          transform: GradientRotation(_c.value * 2 * math.pi),
          tileMode: TileMode.mirror,
        ).createShader(bounds),
        child: child,
      ),
    );
  }
}

class _GlitchText extends StatefulWidget {
  const _GlitchText({required this.child});

  final Widget child;

  @override
  State<_GlitchText> createState() => _GlitchTextState();
}

class _GlitchTextState extends State<_GlitchText> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final _rnd = math.Random();

  // Current frame's jitter — regenerated a few times a second, not every
  // frame, so it reads as choppy digital noise rather than a smooth shake.
  // `_burst` is 0 for a resting frame (the common case: crisp, no ghost)
  // and 1 for a glitch frame.
  double _shift = 0; // px, the chromatic split for this frame
  double _burst = 0;
  double _sliceTop = 0, _sliceH = 0, _sliceShift = 0;
  int _lastTick = -1;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Split scales with the glyph size so the effect reads the same on a
  /// 10px level chip and a 22px name — an absolute px shift is invisible on
  /// one and shreds the other.
  double get _fontSize {
    final s = DefaultTextStyle.of(context).style.fontSize ?? 14;
    return s.clamp(8.0, 48.0);
  }

  void _maybeReroll() {
    final tick = (_c.value * 10).floor(); // ~10 glitch frames/sec
    if (tick == _lastTick) return;
    _lastTick = tick;
    // Only ~1 frame in 4 glitches; the rest are still and crisp.
    final active = _rnd.nextDouble() < 0.28;
    if (!active) {
      _burst = 0;
      _shift = 0;
      _sliceH = 0;
      return;
    }
    _burst = 1;
    // Split proportional to font size (~8–18% of an em), capped small.
    _shift = _fontSize * (0.08 + _rnd.nextDouble() * 0.10);
    if (_rnd.nextDouble() < 0.55) {
      _sliceH = _fontSize * (0.18 + _rnd.nextDouble() * 0.35);
      _sliceTop = _rnd.nextDouble();
      _sliceShift = (_rnd.nextDouble() - 0.5) * _fontSize * 0.9;
    } else {
      _sliceH = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        _maybeReroll();

        // Resting frame: just the crisp original, no Stack, no ghosts.
        if (_burst == 0) return widget.child;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Chromatic-aberration ghosts — semi-transparent so they read
            // as fringes, not a second copy, and gone entirely on rest.
            Transform.translate(
              offset: Offset(-_shift, 0),
              child: Opacity(opacity: 0.55, child: _tinted(const Color(0xFFFF0040))),
            ),
            Transform.translate(
              offset: Offset(_shift, 0),
              child: Opacity(opacity: 0.55, child: _tinted(const Color(0xFF00E5FF))),
            ),
            // The crisp white original on top.
            widget.child,
            // A displaced horizontal slice — the "torn scanline". Wrapped
            // in Positioned.fill so LayoutBuilder can measure, and the
            // slice is a *non-positioned* child clipped to a band.
            if (_sliceH > 0)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final h = constraints.maxHeight.isFinite
                        ? constraints.maxHeight
                        : _fontSize * 1.3;
                    final top = (_sliceTop * (h - _sliceH)).clamp(0.0, h);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: _sliceShift,
                          top: top,
                          child: ClipRect(
                            clipper: _SliceClipper(_sliceH),
                            child: widget.child,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _tinted(Color color) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (b) => LinearGradient(colors: [color, color]).createShader(b),
        child: widget.child,
      );
}

class _SliceClipper extends CustomClipper<Rect> {
  const _SliceClipper(this.height);
  final double height;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width, height.clamp(0, size.height));

  @override
  bool shouldReclip(_SliceClipper old) => old.height != height;
}
