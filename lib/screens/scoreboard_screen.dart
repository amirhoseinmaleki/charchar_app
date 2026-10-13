import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/round.dart';
import '../providers/room_provider.dart';
import '../providers/round_provider.dart';
import '../providers/sound_provider.dart';
import '../services/iap/store_config.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/persian_numbers.dart';
import '../utils/scoring_display.dart';
import '../utils/name_color.dart';
import '../widgets/cartoon_pedestal.dart';
import '../widgets/floating_letters_background.dart';
import '../widgets/gradient_button.dart';
import '../widgets/npc_badge.dart';
import '../widgets/player_avatar.dart';
import '../widgets/p_text.dart';
import '../widgets/share_result_card.dart';

class ScoreboardScreen extends ConsumerStatefulWidget {
  const ScoreboardScreen({super.key, required this.roomCode});

  final String roomCode;

  @override
  ConsumerState<ScoreboardScreen> createState() => _ScoreboardScreenState();
}

class _ScoreboardScreenState extends ConsumerState<ScoreboardScreen> {
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    // Final scoreboard is shown exactly once per game — this is the
    // "game ended, showing scores" moment described in the request.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(soundServiceProvider).playWinner();
    });
  }

  @override
  Widget build(BuildContext context) {
    final roundState = ref.watch(roundControllerProvider);
    final scoreboard = sortScoreboardDescending(
      roundState.finalScoreboard ?? const [],
    );
    final room = ref.watch(roomControllerProvider).room;
    final showNpcBadge = room?.isSoloGame ?? false;

    if (scoreboard.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final top3 = scoreboard.take(3).toList();
    final roundsPlayed =
        room?.settings.roundsPerGame ??
        (roundState.currentRound?.roundIndex ?? 0) + 1;
    final categoriesPerRound = room?.settings.categories.length ?? 0;

    final screenHeight = MediaQuery.of(context).size.height;
    final isShortScreen = screenHeight < 720;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ref.read(roundControllerProvider.notifier).reset();
        ref.read(roomControllerProvider.notifier).leaveRoom();
        context.go('/');
      },
      child: Scaffold(
        body: LetteredBackdrop(
          child: SafeArea(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                    vertical: isShortScreen ? AppSpacing.sm : AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PText(
                        'نتیجه نهایی',
                        textAlign: TextAlign.center,
                        style: (isShortScreen
                                ? Theme.of(context).textTheme.titleLarge
                                : Theme.of(context).textTheme.headlineMedium)
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: isShortScreen ? AppSpacing.sm : AppSpacing.md),
                      _Podium(
                        top3: top3,
                        showNpcBadge: showNpcBadge,
                        compact: isShortScreen,
                      ),
                      if (scoreboard.length > 3) ...[
                        SizedBox(height: isShortScreen ? AppSpacing.xs : AppSpacing.sm),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: scoreboard.length - 3,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 4),
                          itemBuilder: (context, i) {
                            final rank = i + 4;
                            final entry = scoreboard[i + 3];
                            return _RankRow(
                              rank: rank,
                              entry: entry,
                              showNpcBadge: showNpcBadge,
                            );
                          },
                        ),
                      ],
                      SizedBox(height: isShortScreen ? AppSpacing.xs : AppSpacing.sm),
                      _StatsStrip(
                        rounds: roundsPlayed,
                        categoriesPerRound: categoriesPerRound,
                        players: scoreboard.length,
                        compact: isShortScreen,
                      ),
                      SizedBox(height: isShortScreen ? AppSpacing.sm : AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: GradientButton(
                              label: 'اشتراک‌گذاری نتیجه',
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                              ),
                              isLoading: _isSharing,
                              onTap: _isSharing
                                  ? null
                                  : () =>
                                        _shareResult(scoreboard, showNpcBadge),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: GradientButton(
                              label: 'بازی دوباره',
                              gradient: const LinearGradient(
                                colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                              ),
                              onTap: () {
                                ref
                                    .read(roundControllerProvider.notifier)
                                    .reset();
                                ref
                                    .read(roomControllerProvider.notifier)
                                    .leaveRoom();
                                context.go('/');
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      GradientButton(
                        label: 'مشاهده برترین بازیکنان',
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF5C542), Color(0xFFE07A2E)],
                        ),
                        onTap: () {
                          ref.read(roundControllerProvider.notifier).reset();
                          ref.read(roomControllerProvider.notifier).leaveRoom();
                          context.go('/');
                          context.push('/leaderboard');
                        },
                      ),
                    ],
                  ),
                ),
                const _ConfettiOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _shareResult(
    List<ScoreboardEntry> scoreboard,
    bool showNpcBadge,
  ) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    final storeLine = StoreConfig.isMyket
        ? 'دانلود از مایکت: https://myket.ir/app/com.PardisSaz.game'
        : 'دانلود از کافه‌بازار: https://cafebazaar.ir/app/com.PardisSaz.game';
    final lines = [
      'نتیجه بازی اسم و فامیل :',
      for (var i = 0; i < scoreboard.length; i++)
        '${i + 1}. ${scoreboard[i].name} — ${scoreboard[i].score} امتیاز',
      '',
      storeLine,
    ];
    final text = lines.join('\n');

    try {
      final pngBytes = await captureWidgetAsPng(
        context,
        ShareResultCard(scoreboard: scoreboard, showNpcBadge: showNpcBadge),
      );

      if (!mounted) return;

      if (pngBytes != null) {
        final tempDir = await getTemporaryDirectory();
        // share_plus's bundled Android FileProvider only grants access under
        // <cache>/share_plus/ — writing there directly (rather than the
        // cache root) is required for shareXFiles to work on Android.
        final shareDir = Directory('${tempDir.path}/share_plus');
        await shareDir.create(recursive: true);
        final file = File('${shareDir.path}/esmvafamil_result.png');
        await file.writeAsBytes(pngBytes, flush: true);
        await Share.shareXFiles([XFile(file.path)], text: text);
      } else {
        // Rendering failed for some reason — still let the player share the
        // text-only result rather than doing nothing.
        await Share.share(text);
      }
    } catch (_) {
      if (!mounted) return;
      // Native share sheet unavailable/failed — fall back to the clipboard
      // so the player still walks away with something to paste.
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: PText('نتیجه کپی شد')));
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }
}

class _Podium extends StatelessWidget {
  const _Podium({
    required this.top3,
    required this.showNpcBadge,
    this.compact = false,
  });

  final List<ScoreboardEntry> top3;
  final bool showNpcBadge;
  final bool compact;

  ScoreboardEntry? _at(int index) => index < top3.length ? top3[index] : null;

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;
    final h1 = compact ? 95.0 : 130.0;
    final h2 = compact ? 65.0 : 90.0;
    final h3 = compact ? 45.0 : 60.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _PodiumStand(
            entry: _at(1),
            standHeight: h2,
            color: gameTheme.silverColor,
            rank: 2,
            delay: 150,
            showNpcBadge: showNpcBadge,
            compact: compact,
          ),
        ),
        Expanded(
          child: _PodiumStand(
            entry: _at(0),
            standHeight: h1,
            color: gameTheme.goldColor,
            rank: 1,
            delay: 0,
            showNpcBadge: showNpcBadge,
            compact: compact,
          ),
        ),
        Expanded(
          child: _PodiumStand(
            entry: _at(2),
            standHeight: h3,
            color: const Color(0xFFCD7F32),
            rank: 3,
            delay: 300,
            showNpcBadge: showNpcBadge,
            compact: compact,
          ),
        ),
      ],
    );
  }
}

class _PodiumStand extends StatelessWidget {
  const _PodiumStand({
    required this.entry,
    required this.standHeight,
    required this.color,
    required this.rank,
    required this.delay,
    required this.showNpcBadge,
    this.compact = false,
  });

  final ScoreboardEntry? entry;
  final double standHeight;
  final Color color;
  final int rank;
  final int delay;
  final bool showNpcBadge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (entry == null) return const SizedBox.shrink();

    final avatarRadius = compact ? 18.0 : 22.0;

    return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: compact ? 2 : 3),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: compact ? 6 : 10,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: PlayerAvatar(
                name: entry!.name,
                avatarUrl: entry!.avatarUrl,
                radius: avatarRadius,
              ),
            ),
            const SizedBox(height: 2),
            ColoredName(
              entry!.name,
              colorHex: entry!.nameColorHex,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (compact
                      ? Theme.of(context).textTheme.bodySmall
                      : Theme.of(context).textTheme.bodyMedium)
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (showNpcBadge && entry!.isNpc) ...[
              const SizedBox(height: 2),
              const NpcBadge(),
            ],
            PText(
              entry!.score.toPersianString(),
              style: (compact
                      ? Theme.of(context).textTheme.titleSmall
                      : Theme.of(context).textTheme.titleMedium)
                  ?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: compact ? 4 : AppSpacing.sm),
            CartoonPedestal(height: standHeight, color: color, rank: rank),
          ],
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: delay.ms)
        .slideY(
          begin: 0.3,
          end: 0,
          duration: 400.ms,
          delay: delay.ms,
          curve: Curves.easeOut,
        );
  }
}

/// A row of three cartoon stat tiles: rounds, categories/round, players.
class _StatsStrip extends StatelessWidget {
  const _StatsStrip({
    required this.rounds,
    required this.categoriesPerRound,
    required this.players,
    this.compact = false,
  });

  final int rounds;
  final int categoriesPerRound;
  final int players;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.replay_rounded,
            value: rounds,
            label: 'دور',
            compact: compact,
          ),
        ),
        SizedBox(width: compact ? 6 : AppSpacing.sm),
        Expanded(
          child: _StatTile(
            icon: Icons.category_rounded,
            value: categoriesPerRound,
            label: 'دسته در هر دور',
            compact: compact,
          ),
        ),
        SizedBox(width: compact ? 6 : AppSpacing.sm),
        Expanded(
          child: _StatTile(
            icon: Icons.people_alt_rounded,
            value: players,
            label: 'بازیکن',
            compact: compact,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.compact = false,
  });

  final IconData icon;
  final int value;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: compact ? 6 : AppSpacing.sm,
        horizontal: 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2140),
        borderRadius: BorderRadius.circular(compact ? 10 : AppRadius.md),
        border: Border.all(color: const Color(0xFF4A3A6E), width: compact ? 2 : 3),
      ),
      child: Column(
        children: [
          Icon(icon, size: compact ? 16 : 18, color: Colors.white.withValues(alpha: 0.7)),
          const SizedBox(height: 2),
          PText(
            value.toPersianString(),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: compact ? 15 : 18,
            ),
          ),
          PText(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 9 : 10,
              color: Colors.white.withValues(alpha: 0.55),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// One row in the full ranking list: rank pill, avatar, name (+NPC badge),
/// score.
class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.entry,
    required this.showNpcBadge,
  });

  final int rank;
  final ScoreboardEntry entry;
  final bool showNpcBadge;

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;
    final medal = switch (rank) {
      1 => gameTheme.goldColor,
      2 => gameTheme.silverColor,
      3 => const Color(0xFFCD7F32),
      _ => null,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2140),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: medal ?? const Color(0xFF4A3A6E),
          width: medal != null ? 2.5 : 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (medal ?? Colors.white).withValues(alpha: 0.15),
              border: Border.all(color: medal ?? Colors.white24, width: 2),
            ),
            child: PText(
              rank.toPersianString(),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: medal ?? Colors.white,
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
                    style: const TextStyle(fontWeight: FontWeight.w700),
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
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _ConfettiOverlay extends StatelessWidget {
  const _ConfettiOverlay();

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;
    final colors = [
      gameTheme.goldColor,
      gameTheme.silverColor,
      gameTheme.successColor,
      Colors.pinkAccent,
    ];
    final random = Random(7);
    final screenWidth = MediaQuery.of(context).size.width;

    return IgnorePointer(
      child: SizedBox.expand(
        child: Stack(
          children: List.generate(18, (i) {
            final left = random.nextDouble();
            final delay = random.nextInt(400);
            final color = colors[i % colors.length];
            return Positioned(
              top: -20,
              left: left * screenWidth,
              child:
                  Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )
                      .animate()
                      .moveY(
                        begin: 0,
                        end: 600,
                        duration: 1800.ms,
                        delay: delay.ms,
                        curve: Curves.easeIn,
                      )
                      .fadeOut(delay: (delay + 1200).ms, duration: 600.ms),
            );
          }),
        ),
      ),
    );
  }
}
