import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../theme/app_theme.dart';
import './p_text.dart';

/// A player's avatar. Pass [avatarUrl] (a server-relative path like
/// `/assets/avatar/avatar_ninja.png` or the shared default) to show their
/// equipped image; when null it falls back to the shared default avatar,
/// and if that fails to load (offline, missing file) to a colored
/// initial-letter circle.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, required this.name, this.avatarUrl, this.radius = 20});

  final String name;
  final String? avatarUrl;
  final double radius;

  static const _defaultAvatarPath = '/assets/avatar/defultavatar.png';

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;
    final serverUrl = dotenv.env['SERVER_URL'] ?? 'https://api.woundai.ir';
    final size = radius * 2;
    final path = (avatarUrl != null && avatarUrl!.isNotEmpty) ? avatarUrl! : _defaultAvatarPath;

    return CircleAvatar(
      radius: radius,
      backgroundColor: gameTheme.heroGradient.colors.first,
      child: ClipOval(
        child: Image.network(
          '$serverUrl$path',
          key: ValueKey('$serverUrl$path'),
          width: size,
          height: size,
          fit: BoxFit.cover,
          // Keep the previous frame on screen while a new URL loads (e.g.
          // right after equipping a different avatar) so it swaps cleanly
          // instead of flashing to a spinner.
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => _initials(),
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : SizedBox(
                  width: size * 0.5,
                  height: size * 0.5,
                  child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
        ),
      ),
    );
  }

  Widget _initials() {
    return PText(
      name.isNotEmpty ? name[0] : '؟',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: radius * 0.8),
    );
  }
}
