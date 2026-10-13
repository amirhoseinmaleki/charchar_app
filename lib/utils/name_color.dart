import 'package:flutter/material.dart';
import '../widgets/animated_name_effects.dart';

export '../widgets/animated_name_effects.dart'
    show
        kRainbowNameColor,
        kGlitchNameColor,
        isRainbowNameColor,
        isGlitchNameColor,
        isAnimatedNameColor;

/// Parses a server-sent name-color hex (`#RRGGBB`, `#AARRGGBB`, or the same
/// without the `#`) into a [Color]. Returns null for null/blank/malformed
/// input — and for an animated sentinel like `rainbow` / `glitch` (which
/// isn't a single colour) — so callers fall back to the default text color.
Color? parseNameColor(String? hex) {
  if (hex == null) return null;
  var value = hex.trim();
  if (value.isEmpty || isAnimatedNameColor(value)) return null;
  if (value.startsWith('#')) value = value.substring(1);
  if (value.length == 6) value = 'FF$value'; // assume opaque
  if (value.length != 8) return null;
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? null : Color(parsed);
}

/// A player's display name tinted with their equipped name-color. When
/// [colorHex] doesn't resolve to a color the name renders in [style] (or
/// the ambient text style) unchanged — so this is safe to use for every
/// name everywhere, colored or not.
///
/// Animated sentinels (`rainbow`, `glitch`) render the name with a
/// per-frame effect instead of a flat colour.
class ColoredName extends StatelessWidget {
  const ColoredName(
    this.name, {
    super.key,
    this.colorHex,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String name;
  final String? colorHex;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;

    if (isAnimatedNameColor(colorHex)) {
      return AnimatedNameEffect(
        hex: colorHex,
        child: Text(
          name,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
          // White base — the effect (ShaderMask / tint layers) colours it.
          style: base.copyWith(color: Colors.white),
        ),
      );
    }

    final color = parseNameColor(colorHex);
    return Text(
      name,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: color == null ? base : base.copyWith(color: color),
    );
  }
}
