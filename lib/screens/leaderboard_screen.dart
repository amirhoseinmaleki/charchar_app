import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/leaderboard.dart';
import '../providers/auth_provider.dart';
import '../providers/leaderboard_provider.dart';
import '../providers/remote_config_provider.dart';
import '../providers/sound_provider.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/name_color.dart';
import '../utils/persian_numbers.dart';
import '../utils/player_level.dart';
import '../widgets/app_back_button.dart';
import '../widgets/cartoon_pedestal.dart';
import '../widgets/floating_letters_background.dart';
import '../widgets/pill_tab_switcher.dart';
import '../widgets/player_avatar.dart';
import '../widgets/p_text.dart';

/// Tabs for "همه زمان‌ها" / "این هفته" / "این ماه", podium for the top 3
/// (same visual language as the Final Scoreboard), and the current user's
/// own row pinned at the bottom if they're outside the visible list.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _scopes = [
    LeaderboardScope.allTime,
    LeaderboardScope.weekly,
    LeaderboardScope.monthly,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _scopes.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const PText('برترین بازیکنان'),
        leading: const AppBackButton(),
      ),
      body: LetteredBackdrop(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.sm,
                AppSpacing.screenPadding,
                AppSpacing.lg,
              ),
              child: PillTabSwitcher(
                controller: _tabController,
                tabs: [
                  for (final scope in _scopes) PillTab(label: scope.labelFa),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  for (final scope in _scopes) _LeaderboardTab(scope: scope),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardTab extends ConsumerWidget {
  const _LeaderboardTab({required this.scope});

  final LeaderboardScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync = ref.watch(leaderboardProvider(scope));
    final myPlayerId = ref.watch(authControllerProvider).player?.id;

    return resultAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(
        onRetry: () => ref.invalidate(leaderboardProvider(scope)),
      ),
      data: (result) {
        if (result.entries.isEmpty) {
          return const _EmptyState();
        }

        final top3 = result.entries.take(3).toList();
        final rest = result.entries.skip(3).toList();
        // The caller's own row within the visible list, matched by `rank`
        // (ranks are dense + unique — leaderboard.md). Non-null → they're in
        // the top 100 and that row gets a distinct background. Null but
        // myRank set → they're past the list; pin a fixed row at the bottom.
        final myEntryInList = result.myEntryInList;
        final showPinnedRow = myEntryInList == null && result.myRank != null;

        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(leaderboardProvider(scope)),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  children: [
                    _LeaderboardPodium(top3: top3, myEntry: myEntryInList),
                    const SizedBox(height: AppSpacing.xl),
                    for (final entry in rest)
                      _LeaderboardRow(
                        entry: entry,
                        isMe: identical(entry, myEntryInList),
                      ).animate().fadeIn(
                        duration: 250.ms,
                        delay: (20 * entry.rank).ms,
                      ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
            if (showPinnedRow)
              _PinnedMyRankBar(
                entry: LeaderboardEntry(
                  playerId: myPlayerId ?? '',
                  nickname: 'شما',
                  score: result.myRank!.score,
                  rank: result.myRank!.rank,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LeaderboardPodium extends StatelessWidget {
  const _LeaderboardPodium({required this.top3, this.myEntry});

  final List<LeaderboardEntry> top3;

  /// The caller's own entry if it's one of the top 3 — that stand gets a
  /// highlighted avatar ring.
  final LeaderboardEntry? myEntry;

  LeaderboardEntry? _at(int index) => index < top3.length ? top3[index] : null;

  bool _isMe(LeaderboardEntry? e) => e != null && identical(e, myEntry);

  @override
  Widget build(BuildContext context) {
    if (top3.isEmpty) return const SizedBox.shrink();
    final gameTheme = context.gameTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _Stand(
            entry: _at(1),
            standHeight: 92,
            color: gameTheme.silverColor,
            rank: 2,
            delay: 150,
            isMe: _isMe(_at(1)),
          ),
        ),
        Expanded(
          child: _Stand(
            entry: _at(0),
            standHeight: 128,
            color: gameTheme.goldColor,
            rank: 1,
            delay: 0,
            isMe: _isMe(_at(0)),
          ),
        ),
        Expanded(
          child: _Stand(
            entry: _at(2),
            standHeight: 68,
            color: const Color(0xFFCD7F32),
            rank: 3,
            delay: 300,
            isMe: _isMe(_at(2)),
          ),
        ),
      ],
    );
  }
}

class _Stand extends StatelessWidget {
  const _Stand({
    required this.entry,
    required this.standHeight,
    required this.color,
    required this.rank,
    required this.delay,
    this.isMe = false,
  });

  final LeaderboardEntry? entry;
  final double standHeight;
  final Color color;
  final int rank;
  final int delay;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    if (entry == null) return const SizedBox.shrink();
    final accent = context.gameTheme.heroGradient.colors.first;
    return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              decoration: isMe
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: accent, width: 2.5),
                    )
                  : null,
              padding: isMe ? const EdgeInsets.all(2) : EdgeInsets.zero,
              child: PlayerAvatar(
                name: entry!.nickname,
                avatarUrl: entry!.avatarUrl,
                radius: 20,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            ColoredName(
              entry!.nickname,
              colorHex: entry!.nameColorHex,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            PText(
              entry!.score.toPersianStringGrouped(),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: color),
            ),
            const SizedBox(height: AppSpacing.xs),
            _LevelChip(score: entry!.score),
            const SizedBox(height: AppSpacing.sm),
            CartoonPedestal(
              height: standHeight,
              color: color,
              rank: rank,
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: delay.ms)
        .slideY(begin: 0.3, end: 0, duration: 400.ms, delay: delay.ms);
  }
}

/// Compact "سطح N" chip for a leaderboard row / podium stand. The
/// leaderboard API only carries a score per entry (no per-row level), so
/// the level is derived here from that score against the live leveling
/// curve from `GET /config/client`.
class _LevelChip extends ConsumerWidget {
  const _LevelChip({required this.score});

  final int score;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gold = context.gameTheme.goldColor;
    final leveling =
        ref.watch(remoteConfigValueProvider.select((c) => c.config.leveling));
    final level = PlayerLevel.fromScore(score, leveling: leveling).level;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: gold.withValues(alpha: 0.5)),
      ),
      child: PText(
        'سطح ${level.toPersianString()}',
        style: TextStyle(color: gold, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.entry,
    required this.isMe,
    this.margin = true,
  });

  final LeaderboardEntry entry;
  final bool isMe;

  /// Bottom margin between rows in the list. Off when the row is used
  /// standalone inside [_PinnedMyRankBar].
  final bool margin;

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;
    final accent = gameTheme.heroGradient.colors.first;
    return Container(
      margin: margin
          ? const EdgeInsets.only(bottom: AppSpacing.sm)
          : EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isMe
            ? accent.withValues(alpha: 0.22)
            : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: isMe
            ? Border.all(color: accent.withValues(alpha: 0.7), width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: PText(
              entry.rank.toPersianString(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          PlayerAvatar(
            name: entry.nickname,
            avatarUrl: entry.avatarUrl,
            radius: 16,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ColoredName(
              entry.nickname,
              colorHex: entry.nameColorHex,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: isMe ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _LevelChip(score: entry.score),
          const SizedBox(width: AppSpacing.sm),
          PText(
            entry.score.toPersianStringGrouped(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

/// The caller's own rank, pinned to the bottom of the screen (outside the
/// scroll) when they're not in the visible top 100. Same row layout as
/// [_LeaderboardRow] but wrapped in an elevated, safe-area'd bar so it
/// reads as "always yours" while the list scrolls behind it.
class _PinnedMyRankBar extends StatelessWidget {
  const _PinnedMyRankBar({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.sm,
            AppSpacing.screenPadding,
            AppSpacing.sm,
          ),
          child: _LeaderboardRow(entry: entry, isMe: true, margin: false),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: PText(
          'هنوز کسی امتیازی کسب نکرده. اولین نفر باش!',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _ErrorState extends ConsumerWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PText(
              'ارتباط با سرور برقرار نشد.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: () {
                ref.read(soundServiceProvider).playButtonClick();
                onRetry();
              },
              child: const PText('تلاش دوباره'),
            ),
          ],
        ),
      ),
    );
  }
}
