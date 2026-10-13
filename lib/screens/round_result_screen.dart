import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/category.dart';
import '../models/player.dart';
import '../models/round.dart';
import '../providers/room_provider.dart';
import '../providers/round_provider.dart';
import '../providers/sound_provider.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/persian_numbers.dart';
import '../utils/scoring_display.dart';
import '../widgets/app_back_button.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/floating_letters_background.dart';
import '../widgets/gradient_button.dart';
import '../widgets/npc_badge.dart';
import '../widgets/p_text.dart';

const _reactionEmojis = ['😂', '🔥', '👏', '😮', '❤️'];

class RoundResultScreen extends ConsumerStatefulWidget {
  const RoundResultScreen({super.key, required this.roomCode});

  final String roomCode;

  @override
  ConsumerState<RoundResultScreen> createState() => _RoundResultScreenState();
}

class _RoundResultScreenState extends ConsumerState<RoundResultScreen> {
  final List<_FloatingReaction> _floatingReactions = [];

  /// Set when the game's final results are ready. Instead of auto-navigating
  /// to the scoreboard, we show a "دیدن نتایج" button and let the player go
  /// when they're done looking at this round's breakdown.
  bool _finalResultsReady = false;

  void _showFloatingReaction(String emoji) {
    final reaction = _FloatingReaction(emoji: emoji, id: UniqueKey());
    setState(() => _floatingReactions.add(reaction));
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(
        () => _floatingReactions.removeWhere((r) => r.id == reaction.id),
      );
    });
  }

  void _sendReaction(String emoji) {
    // Show the sender's own reaction immediately — the server may debounce
    // a very rapid repeat and never echo it back, and even when it does
    // there's a round-trip of lag. The broadcast listener below ignores
    // this player's own id so there's no double pop-up.
    ref.read(soundServiceProvider).playButtonClick();
    _showFloatingReaction(emoji);
    ref
        .read(roundControllerProvider.notifier)
        .sendReaction(widget.roomCode, emoji);
  }

  @override
  Widget build(BuildContext context) {
    final roundState = ref.watch(roundControllerProvider);
    final result = roundState.lastResult;
    final room = ref.watch(roomControllerProvider).room;
    final myPlayerId = ref.watch(roomControllerProvider).myPlayerId;
    final isHost =
        room != null && myPlayerId != null && room.hostId == myPlayerId;
    final isSoloOrOnline =
        room?.isSoloGame == true || room?.isOnlineGame == true;
    final isLastRound =
        room != null &&
        result != null &&
        result.roundIndex + 1 >= room.settings.roundsPerGame;
    final isAutoAdvancing = isSoloOrOnline && !isLastRound;

    ref.listen(roundControllerProvider, (previous, next) {
      if (next.phase == RoundPhase.inRound) {
        context.go('/round', extra: widget.roomCode);
      } else if (next.phase == RoundPhase.gameOver && !_finalResultsReady) {
        // Don't jump straight to the scoreboard — surface a button and let
        // the player open it when they're ready.
        setState(() => _finalResultsReady = true);
      }
    });

    ref.listen(roundControllerProvider.select((s) => s.incomingReaction), (
      previous,
      next,
    ) {
      if (next == null) return;
      // Same event delivered twice — ignore.
      if (previous != null &&
          next.at == previous.at &&
          next.playerId == previous.playerId) {
        return;
      }
      // The sender already showed their own reaction optimistically.
      if (next.playerId == myPlayerId) return;
      _showFloatingReaction(next.stickerId);
    });

    if (result == null || room == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final categoriesInOrder = <CategoryId>[];
    for (final j in result.judgements) {
      if (!categoriesInOrder.contains(j.category)) {
        categoriesInOrder.add(j.category);
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await ConfirmDialog.show(
          context,
          title: 'خروج از بازی؟',
          message: 'در صورت خروج، از بازی فعلی خارج شده و به صفحه اصلی می‌روید.',
          confirmLabel: 'خروج از بازی',
        );
        if (leave == true && context.mounted) {
          ref.read(roundControllerProvider.notifier).reset();
          ref.read(roomControllerProvider.notifier).leaveRoom();
          context.go('/');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: PText('نتیجه دور ${(result.roundIndex + 1).toPersianString()}'),
          leading: AppBackButton(
            onPressed: () async {
              final leave = await ConfirmDialog.show(
                context,
                title: 'خروج از بازی؟',
                message: 'در صورت خروج، از بازی فعلی خارج شده و به صفحه اصلی می‌روید.',
                confirmLabel: 'خروج از بازی',
              );
              if (leave == true && context.mounted) {
                ref.read(roundControllerProvider.notifier).reset();
                ref.read(roomControllerProvider.notifier).leaveRoom();
                context.go('/');
              }
            },
          ),
        ),
        body: LetteredBackdrop(
        child: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        children: [
                          for (var i = 0; i < categoriesInOrder.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.md,
                              ),
                              child:
                                  _CategoryResultCard(
                                        category: categoriesInOrder[i],
                                        judgements: result.judgements
                                            .where(
                                              (j) =>
                                                  j.category ==
                                                  categoriesInOrder[i],
                                            )
                                            .toList(),
                                        players: room.players,
                                        showNpcBadge: room.isSoloGame,
                                      )
                                      .animate()
                                      .fadeIn(
                                        duration: 300.ms,
                                        delay: (i * 120).ms,
                                      )
                                      .slideY(begin: 0.15, end: 0),
                            ),
                          const SizedBox(height: AppSpacing.lg),
                          PText(
                            'امتیازات',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          for (final s in sortScoreboardDescending(
                            result.scoreboard,
                          ))
                            _ScoreRow(
                              entry: s,
                              showNpcBadge: room.isSoloGame,
                              key: ValueKey(
                                '${result.roundIndex}-${s.playerId}',
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ReactionBar(onReact: _sendReaction),
                    const SizedBox(height: AppSpacing.md),
                    if (_finalResultsReady)
                      GradientButton(
                        label: 'دیدن نتایج',
                        onTap: () =>
                            context.go('/scoreboard', extra: widget.roomCode),
                      )
                    else if (isAutoAdvancing)
                      const _NextRoundCountdown()
                    else if (isLastRound)
                      PText(
                        'در حال محاسبه نتیجه نهایی...',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    else if (isHost)
                      GradientButton(
                        label: 'دور بعد',
                        onTap: () => ref
                            .read(roundControllerProvider.notifier)
                            .requestNextRound(widget.roomCode),
                      )
                    else
                      PText(
                        'منتظر میزبان برای شروع دور بعد...',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
              for (final r in _floatingReactions)
                _FloatingReactionWidget(key: r.id, emoji: r.emoji),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// Shown instead of a "دور بعد" button for solo/online games, which the
/// server auto-advances a fixed break after the round ends (see server
/// config `ROUND_RESULT_BREAK_SECONDS`) — this just visualizes that break
/// rather than implying the player needs to press anything. Purely
/// cosmetic: the actual advance is always server-triggered.
class _NextRoundCountdown extends StatefulWidget {
  const _NextRoundCountdown();

  @override
  State<_NextRoundCountdown> createState() => _NextRoundCountdownState();
}

class _NextRoundCountdownState extends State<_NextRoundCountdown> {
  static const _breakSeconds = 5;

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;
    return Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2140),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: const Color(0xFF4A3A6E), width: 3),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 18,
                color: gameTheme.heroGradient.colors.first,
              ),
              const SizedBox(width: AppSpacing.sm),
              PText(
                'دور بعد به‌زودی شروع می‌شود...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: (_breakSeconds * 1000).ms,
          color: gameTheme.heroGradient.colors.last.withValues(alpha: 0.3),
        );
  }
}

class _FloatingReaction {
  _FloatingReaction({required this.emoji, required this.id});
  final String emoji;
  final Key id;
}

class _FloatingReactionWidget extends StatelessWidget {
  const _FloatingReactionWidget({super.key, required this.emoji});

  final String emoji;

  @override
  Widget build(BuildContext context) {
    final random = Random();
    final leftOffset = 0.2 + random.nextDouble() * 0.6;
    return Positioned(
      bottom: 120,
      left: MediaQuery.of(context).size.width * leftOffset,
      child: PText(emoji, style: const TextStyle(fontSize: 32))
          .animate()
          .moveY(begin: 0, end: -220, duration: 2000.ms, curve: Curves.easeOut)
          .fadeOut(duration: 2000.ms),
    );
  }
}

class _ReactionBar extends ConsumerWidget {
  const _ReactionBar({required this.onReact});

  final void Function(String emoji) onReact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final emoji in _reactionEmojis)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: _ReactionButton(emoji: emoji, onTap: () => onReact(emoji)),
          ),
      ],
    );
  }
}

/// A chunky cartoon reaction disc: dark fill, thick dark outline, with a
/// shrink-and-return scale bounce on tap. Matches the other cartoon chips.
class _ReactionButton extends StatefulWidget {
  const _ReactionButton({required this.emoji, required this.onTap});

  final String emoji;
  final VoidCallback onTap;

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton>
    with SingleTickerProviderStateMixin {
  static const _fill = Color(0xFF2A2140);
  static const _outline = Color(0xFF4A3A6E);

  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scale = Tween<double>(begin: 1, end: 0.8).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await _controller.forward();
    await _controller.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _fill,
            shape: BoxShape.circle,
            border: Border.all(color: _outline, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: PText(widget.emoji, style: const TextStyle(fontSize: 20)),
        ),
      ),
    );
  }
}

class _CategoryResultCard extends StatelessWidget {
  const _CategoryResultCard({
    required this.category,
    required this.judgements,
    required this.players,
    required this.showNpcBadge,
  });

  final CategoryId category;
  final List<WordJudgement> judgements;
  final List<Player> players;
  final bool showNpcBadge;

  Player? _playerFor(String playerId) {
    for (final p in players) {
      if (p.id == playerId) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2140),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: const Color(0xFF4A3A6E), width: 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                category.icon,
                size: 18,
                color: Colors.white.withValues(alpha: 0.75),
              ),
              const SizedBox(width: AppSpacing.xs),
              PText(
                category.labelFa,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: DecoratedBox(
              decoration: BoxDecoration(color: Color(0xFF4A3A6E)),
              child: SizedBox(height: 2, width: double.infinity),
            ),
          ),
          for (final j in judgements)
            _JudgementRow(
              judgement: j,
              playerName: _playerFor(j.playerId)?.name ?? '؟',
              isNpc: showNpcBadge && (_playerFor(j.playerId)?.isNpc ?? false),
            ),
        ],
      ),
    );
  }
}

class _JudgementRow extends StatelessWidget {
  const _JudgementRow({
    required this.judgement,
    required this.playerName,
    this.isNpc = false,
  });

  final WordJudgement judgement;
  final String playerName;
  final bool isNpc;

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;
    final tier = scoreTierFor(judgement);

    final Color color;
    final String tierLabel;
    switch (tier) {
      case ScoreTier.unique:
        color = gameTheme.goldColor;
        tierLabel = 'یکتا';
      case ScoreTier.shared:
        color = gameTheme.silverColor;
        tierLabel = 'مشترک';
      case ScoreTier.invalid:
        color = gameTheme.invalidColor;
        tierLabel = 'نامعتبر';
      case ScoreTier.pending:
        color = Colors.amber;
        tierLabel = 'در رأی‌گیری';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF2A2140), width: 2),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: PText(
              judgement.word.isEmpty
                  ? '$playerName${isNpc ? ' (بازیکن مجازی)' : ''}: —'
                  : '$playerName${isNpc ? ' (بازیکن مجازی)' : ''}: ${judgement.word}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          _TierChip(label: tierLabel, color: color),
          const SizedBox(width: AppSpacing.sm),
          PText(
            '${judgement.points.toPersianString()}+',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ).animate().scale(
            begin: const Offset(0.5, 0.5),
            end: const Offset(1, 1),
            duration: 250.ms,
            curve: Curves.elasticOut,
          ),
        ],
      ),
    );
  }
}

/// Small cartoon pill for the score-tier label (یکتا / مشترک / نامعتبر …).
class _TierChip extends StatelessWidget {
  const _TierChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 2),
      ),
      child: PText(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({super.key, required this.entry, required this.showNpcBadge});

  final ScoreboardEntry entry;
  final bool showNpcBadge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                PText(entry.name, style: Theme.of(context).textTheme.bodyLarge),
                if (showNpcBadge && entry.isNpc) ...[
                  const SizedBox(width: AppSpacing.xs),
                  const NpcBadge(),
                ],
              ],
            ),
          ),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: entry.score),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (context, value, child) => PText(
              value.toPersianString(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}
