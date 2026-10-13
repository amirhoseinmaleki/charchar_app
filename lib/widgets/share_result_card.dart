import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/round.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/persian_numbers.dart';
import '../utils/name_color.dart';
import 'npc_badge.dart';
import 'player_avatar.dart';
import 'p_text.dart';

/// A self-contained "share card" summarizing the final scoreboard — built
/// off the live scoreboard UI (which has scrolling lists, confetti, entrance
/// animations) so it always renders as one clean, static image regardless
/// of scroll position or animation state.
class ShareResultCard extends StatelessWidget {
  const ShareResultCard({
    super.key,
    required this.scoreboard,
    required this.showNpcBadge,
  });

  final List<ScoreboardEntry> scoreboard;
  final bool showNpcBadge;

  static const double width = 720;

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;
    final champion = scoreboard.first;
    final rest = scoreboard.skip(1).toList();

    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(gradient: gameTheme.baseGradient),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PText(
              'اسم و فامیل',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            PText(
              'نتیجه نهایی',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: gameTheme.goldColor, width: 3),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: gameTheme.goldColor,
                    size: 40,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  PlayerAvatar(
                    name: champion.name,
                    avatarUrl: champion.avatarUrl,
                    radius: 28,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: ColoredName(
                            champion.name,
                            colorHex: champion.nameColorHex,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                            ),
                          ),
                        ),
                        if (showNpcBadge && champion.isNpc) ...[
                          const SizedBox(width: AppSpacing.xs),
                          const NpcBadge(),
                        ],
                      ],
                    ),
                  ),
                  PText(
                    '${champion.score.toPersianString()} امتیاز',
                    style: TextStyle(
                      color: gameTheme.goldColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
            if (rest.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              for (var i = 0; i < rest.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: _ShareRankRow(
                    rank: i + 2,
                    entry: rest[i],
                    showNpcBadge: showNpcBadge,
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.xl),
            PText(
              'بازی گروهی اسم و فامیل',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareRankRow extends StatelessWidget {
  const _ShareRankRow({
    required this.rank,
    required this.entry,
    required this.showNpcBadge,
  });

  final int rank;
  final ScoreboardEntry entry;
  final bool showNpcBadge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: PText(
              rank.toPersianString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          PlayerAvatar(
            name: entry.name,
            avatarUrl: entry.avatarUrl,
            radius: 16,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: ColoredName(
                    entry.name,
                    colorHex: entry.nameColorHex,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (showNpcBadge && entry.isNpc) ...[
                  const SizedBox(width: AppSpacing.xs),
                  const NpcBadge(),
                ],
              ],
            ),
          ),
          PText(
            entry.score.toPersianString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders [card] off-screen and captures it as a PNG. Must be called with
/// [card] already mounted in the tree via an [Overlay] (see
/// [captureWidgetAsPng]) — [GlobalKey] alone can't rasterize a widget that
/// was never laid out.
Future<Uint8List?> _captureBoundary(GlobalKey key) async {
  final boundary =
      key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;
  final image = await boundary.toImage(pixelRatio: 2.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData?.buffer.asUint8List();
}

/// Mounts [child] into an offstage overlay entry just long enough to
/// rasterize it, then removes it — so callers don't need a visible widget
/// in their own tree to produce a share image.
Future<Uint8List?> captureWidgetAsPng(
  BuildContext context,
  Widget child,
) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final boundaryKey = GlobalKey();
  late OverlayEntry entry;
  final completer = Completer<Uint8List?>();

  entry = OverlayEntry(
    builder: (context) => Positioned(
      // Off-screen but still laid out/painted, which is all
      // RenderRepaintBoundary.toImage needs.
      left: -10000,
      top: 0,
      child: Material(
        color: Colors.transparent,
        child: RepaintBoundary(key: boundaryKey, child: child),
      ),
    ),
  );

  overlay.insert(entry);

  // Two frames: one to build+layout, one to guarantee paint completed
  // before we rasterize.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await WidgetsBinding.instance.endOfFrame;
    final bytes = await _captureBoundary(boundaryKey);
    entry.remove();
    completer.complete(bytes);
  });
  // Kick a frame if nothing else is scheduled to draw one.
  WidgetsBinding.instance.scheduleFrame();

  return completer.future;
}
