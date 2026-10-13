import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../utils/persian_numbers.dart';

/// A chunky, cartoon-style podium block: a rounded pillar in the rank's
/// tint (gold / silver / bronze) with a thick dark outline, a glossy top
/// face, and a big outlined rank numeral. Matches CartoonSlider / Switch.
///
/// Shared by the leaderboard podium and the end-of-game scoreboard.
class CartoonPedestal extends StatelessWidget {
  const CartoonPedestal({
    super.key,
    required this.height,
    required this.color,
    required this.rank,
  });

  final double height;
  final Color color;
  final int rank;

  static const _outline = Color(0xFF2A2140);

  @override
  Widget build(BuildContext context) {
    final light = Color.lerp(color, Colors.white, 0.55)!;
    final deep = Color.lerp(color, Colors.black, 0.35)!;

    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [light, color, deep],
          stops: const [0.0, 0.35, 1.0],
        ),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.md),
        ),
        border: Border.all(color: _outline, width: 3),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glossy highlight across the top face.
          Positioned(
            top: 4,
            left: 8,
            right: 8,
            child: Container(
              height: height * 0.22,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
          ),
          // Rank numeral — white fill with a dark outline stroke.
          Stack(
            children: [
              Text(
                rank.toPersianString(),
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 4
                    ..color = _outline,
                ),
              ),
              Text(
                rank.toPersianString(),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
