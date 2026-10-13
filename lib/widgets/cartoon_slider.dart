import 'package:flutter/material.dart';

/// A chunky, cartoon-style slider matching [CartoonProgressBar]'s look: a
/// rounded dark track with a thick outline, a glossy golden fill, and a
/// round golden knob with its own outline. Drag or tap anywhere on the
/// track to set the value.
///
/// [value] is 0.0–1.0; [onChanged] fires continuously while dragging.
class CartoonSlider extends StatelessWidget {
  const CartoonSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.height = 22,
    this.onChangeEnd,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double height;

  static const _gold = Color(0xFFF5C542);
  static const _goldDeep = Color(0xFFE0A21E);
  static const _goldLight = Color(0xFFFFE9A8);
  static const _track = Color(0xFF2A2140);
  static const _outline = Color(0xFF4A3A6E);

  @override
  Widget build(BuildContext context) {
    final h = height;
    final radius = h / 2;
    final knob = h + 10;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Knob centre travels between [radius] and [width - radius].
        final usable = (width - knob).clamp(0.0, double.infinity);

        void emit(double dx, {bool end = false}) {
          final v = ((dx - knob / 2) / (usable == 0 ? 1 : usable)).clamp(0.0, 1.0);
          onChanged(v);
          if (end) onChangeEnd?.call(v);
        }

        final v = value.clamp(0.0, 1.0);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => emit(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => emit(d.localPosition.dx),
          onHorizontalDragEnd: (_) => onChangeEnd?.call(v),
          child: SizedBox(
            height: knob,
            width: width,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Track
                Container(
                  height: h,
                  decoration: BoxDecoration(
                    color: _track,
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(color: _outline, width: 3),
                  ),
                ),
                // Fill up to the knob centre.
                Padding(
                  padding: const EdgeInsets.all(3),
                  child: FractionallySizedBox(
                    widthFactor: ((knob / 2 + usable * v) / width).clamp(0.02, 1.0),
                    child: Container(
                      height: h - 6,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [_goldLight, _gold, _goldDeep],
                          stops: [0.0, 0.5, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(radius),
                        boxShadow: const [
                          BoxShadow(color: Color(0x66F5C542), blurRadius: 10, spreadRadius: -1),
                        ],
                      ),
                    ),
                  ),
                ),
                // Knob
                Positioned(
                  left: usable * v,
                  child: Container(
                    width: knob,
                    height: knob,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_goldLight, _gold, _goldDeep],
                      ),
                      border: Border.all(color: _outline, width: 3),
                      boxShadow: const [
                        BoxShadow(color: Color(0x55000000), blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: knob * 0.28,
                        height: knob * 0.28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
