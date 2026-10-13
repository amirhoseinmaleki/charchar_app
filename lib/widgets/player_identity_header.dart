import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/name_color.dart';
import '../utils/persian_numbers.dart';
import 'player_avatar.dart';
import 'p_text.dart';

/// The shared player-identity block used on both Home and Profile: the
/// gradient-ringed avatar, a level badge on its upper-left, and the
/// nickname on a nameplate that tucks under the avatar's lower edge.
class PlayerIdentityHeader extends StatelessWidget {
  const PlayerIdentityHeader({
    super.key,
    required this.nickname,
    this.avatarUrl,
    this.nameColorHex,
    this.level,
    this.avatarRadius = 48,
  });

  final String? nickname;
  final String? avatarUrl;
  final String? nameColorHex;

  /// Null hides the level badge (e.g. before the leaderboard fetch lands).
  final int? level;

  final double avatarRadius;

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        // Avatar, with room reserved below it for the overlapping nameplate.
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gameTheme.heroGradient,
            ),
            child: PlayerAvatar(
              name: nickname ?? '؟',
              avatarUrl: avatarUrl,
              radius: avatarRadius,
            ),
          ),
        ),
        // Nickname nameplate — pulled up so it tucks under the avatar's
        // lower edge rather than sitting below it.
        Positioned(
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: gameTheme.heroGradient.colors.first.withValues(
                  alpha: 0.35,
                ),
              ),
            ),
            child: ColoredName(
              nickname ?? 'بازیکن',
              colorHex: nameColorHex,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ),
        // Level badge, on the avatar's upper-left.
        if (level != null)
          Positioned(top: -4, left: -16, child: _LevelBadge(level: level!)),
      ],
    );
  }
}

/// The player's level, shown as a small gold badge on the avatar.
class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gameTheme.goldColor, const Color(0xFFE0A21E)],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: gameTheme.goldColor.withValues(alpha: 0.45),
            blurRadius: 8,
            spreadRadius: -1,
          ),
        ],
      ),
      child: PText(
        'سطح ${level.toPersianString()}',
        style: const TextStyle(
          color: Color(0xFF3A2A00),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
