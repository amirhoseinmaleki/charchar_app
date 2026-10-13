import 'dart:async';
import 'package:animated_button/animated_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/category.dart';
import '../models/round.dart';
import '../providers/room_provider.dart';
import '../providers/round_provider.dart';
import '../providers/sound_provider.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/persian_numbers.dart';
import '../widgets/app_back_button.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/p_text.dart';

/// Shown whenever a submitted word isn't in the dictionary but is plausible
/// — the group decides by majority vote instead of the server silently
/// rejecting it. This directly addresses the "the app wrongly invalidated
/// my word" complaint pattern called out in the spec.
class VoteScreen extends ConsumerStatefulWidget {
  const VoteScreen({super.key, required this.roomCode});

  final String roomCode;

  @override
  ConsumerState<VoteScreen> createState() => _VoteScreenState();
}

class _VoteScreenState extends ConsumerState<VoteScreen> {
  bool? _myVote;
  String? _votedForId;

  void _castVote(String voteId, bool accept) {
    if (_votedForId == voteId) return; // already voted on this word
    setState(() {
      _myVote = accept;
      _votedForId = voteId;
    });
    ref.read(roundControllerProvider.notifier).castVote(widget.roomCode, voteId, accept);
  }

  @override
  Widget build(BuildContext context) {
    final roundState = ref.watch(roundControllerProvider);
    final vote = roundState.activeVote;
    final myPlayerId = ref.watch(roomControllerProvider).myPlayerId;

    ref.listen(roundControllerProvider, (previous, next) {
      if (next.phase == RoundPhase.result) {
        context.go('/round-result', extra: widget.roomCode);
      }
    });

    // Reset local vote-cast tracking whenever a new dispute starts.
    if (vote != null && vote.voteId != _votedForId) {
      _myVote = null;
    }

    if (vote == null) {
      // All disputes for this round just resolved and the next voteStart
      // (if any) hasn't arrived yet — the listener above will move on to
      // round-result shortly; show the last outcome in the meantime rather
      // than a bare spinner.
      final lastResult = roundState.lastVoteResult;
      if (lastResult != null) {
        return Scaffold(body: SafeArea(child: _VoteResultBanner(result: lastResult)));
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isAuthor = myPlayerId != null && vote.authorPlayerIds.contains(myPlayerId);
    final hasVoted = _votedForId == vote.voteId;

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
          title: const PText('رأی‌گیری کلمه'),
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
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.lg),
              PText(
                'آیا این کلمه رو قبول دارید؟',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              _WordCard(category: vote.category, word: vote.word)
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
              const SizedBox(height: AppSpacing.xxl),
              if (isAuthor)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: PText(
                    'شما نویسنده این کلمه هستید و در این رأی‌گیری شرکت نمی‌کنید',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else if (!hasVoted)
                Row(
                  children: [
                    Expanded(
                      child: _VoteButton(
                        label: 'قبول دارم',
                        color: context.gameTheme.successColor,
                        icon: Icons.check_circle_outline,
                        onTap: () => _castVote(vote.voteId, true),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _VoteButton(
                        label: 'قبول ندارم',
                        color: context.gameTheme.invalidColor,
                        icon: Icons.cancel_outlined,
                        onTap: () => _castVote(vote.voteId, false),
                      ),
                    ),
                  ],
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: PText(
                    _myVote == true ? 'رأی شما: قبول دارم' : 'رأی شما: قبول ندارم',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: _myVote == true ? context.gameTheme.successColor : context.gameTheme.invalidColor,
                        ),
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              _VoteCountdown(deadline: DateTime.fromMillisecondsSinceEpoch(vote.deadline)),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _VoteResultBanner extends StatelessWidget {
  const _VoteResultBanner({required this.result});

  final VoteResult result;

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;
    final color = result.accepted ? gameTheme.successColor : gameTheme.invalidColor;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(result.accepted ? Icons.check_circle : Icons.cancel, color: color, size: 56)
                .animate()
                .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1), duration: 300.ms),
            const SizedBox(height: AppSpacing.lg),
            PText(
              result.accepted ? 'کلمه پذیرفته شد' : 'کلمه رد شد',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color),
            ),
            const SizedBox(height: AppSpacing.sm),
            PText('${result.word} (${result.category.labelFa})', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.sm),
            PText(
              'موافق: ${result.yes.toPersianString()} — مخالف: ${result.no.toPersianString()}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({required this.category, required this.word});

  final CategoryId category;
  final String word;

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: gameTheme.heroGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          PText(category.labelFa, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: AppSpacing.sm),
          PText(
            word,
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _VoteButton extends ConsumerWidget {
  const _VoteButton({required this.label, required this.color, required this.icon, required this.onTap});

  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  static const _height = 96.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth && constraints.maxWidth.isFinite ? constraints.maxWidth : 150.0;

        return AnimatedButton(
          width: width,
          height: _height,
          borderRadius: AppRadius.md,
          color: color.withValues(alpha: 0.15),
          onPressed: () {
            ref.read(soundServiceProvider).playButtonClick();
            onTap();
          },
          child: Container(
            width: width,
            height: _height,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: AppSpacing.xs),
                PText(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VoteCountdown extends StatefulWidget {
  const _VoteCountdown({required this.deadline});

  final DateTime deadline;

  @override
  State<_VoteCountdown> createState() => _VoteCountdownState();
}

class _VoteCountdownState extends State<_VoteCountdown> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
  }

  void _tick() {
    final remaining = widget.deadline.difference(DateTime.now());
    setState(() => _remaining = remaining.isNegative ? Duration.zero : remaining);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = (_remaining.inMilliseconds / 1000).ceil();
    return PText('${seconds.toPersianString()} ثانیه تا پایان رأی‌گیری', style: Theme.of(context).textTheme.bodyMedium);
  }
}
