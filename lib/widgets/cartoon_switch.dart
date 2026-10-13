import 'package:flutter/material.dart';

/// A chunky, cartoon-style on/off toggle matching [CartoonSlider]: a
/// rounded pill track with a thick outline and a glossy round knob that
/// slides between the ends. Off = dark track + grey knob, on = golden
/// track + golden knob.
class CartoonSwitch extends StatelessWidget {
  const CartoonSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.height = 30,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final double height;

  static const _gold = Color(0xFFF5C542);
  static const _goldDeep = Color(0xFFE0A21E);
  static const _goldLight = Color(0xFFFFE9A8);
  static const _trackOff = Color(0xFF2A2140);
  static const _trackOn = Color(0xFFB9821A);
  static const _outline = Color(0xFF4A3A6E);
  static const _outlineOn = Color(0xFF6E4E12);
  static const _knobOff = Color(0xFFBDB6D0);

  @override
  Widget build(BuildContext context) {
    final h = height;
    final w = h * 1.9;
    final knob = h - 6;
    final radius = h / 2;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: w,
        height: h,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? _trackOn : _trackOff,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: value ? _outlineOn : _outline, width: 3),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: knob,
            height: knob,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: value
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_goldLight, _gold, _goldDeep],
                    )
                  : const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFE6E2F0), _knobOff],
                    ),
              border: Border.all(
                color: value ? _outlineOn : _outline,
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 3,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
