import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/player.dart';
import '../providers/chat_provider.dart';
import '../providers/room_provider.dart';
import '../providers/round_provider.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../providers/sound_provider.dart';
import '../utils/persian_numbers.dart';
import '../widgets/app_back_button.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/floating_letters_background.dart';
import '../widgets/gradient_button.dart';
import '../widgets/npc_badge.dart';
import '../widgets/player_avatar.dart';
import '../utils/name_color.dart';
import '../widgets/p_text.dart';

class LobbyScreen extends ConsumerWidget {
  const LobbyScreen({super.key, required this.roomCode});

  final String roomCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameTheme = context.gameTheme;
    final roomState = ref.watch(roomControllerProvider);
    final room = roomState.room;
    final myPlayerId = roomState.myPlayerId;
    final isHost =
        room != null && myPlayerId != null && room.hostId == myPlayerId;
    final isOnlineGame = room?.isOnlineGame ?? false;
    final humanCount = room?.players.where((p) => !p.isNpc).length ?? 0;
    final canStart = isHost && !isOnlineGame && humanCount >= 2;

    ref.listen(roomControllerProvider, (previous, next) {
      if (previous?.room != null && next.room == null) {
        // Room disappeared (host cancelled / kicked out) — bail to Home.
        if (context.canPop()) context.pop();
      }
    });

    ref.listen(roundControllerProvider, (previous, next) {
      if (next.phase == RoundPhase.inRound) {
        context.go('/round', extra: roomCode);
      }
    });

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        // A guest leaving the lobby really does leave (frees their slot,
        // refunds the join charge if the game hasn't started). The host
        // pressing back just minimises the lobby — the room stays alive and
        // Home shows a "return to lobby" banner — so they don't accidentally
        // destroy their own room. The host leaves for real via the explicit
        // "حذف اتاق" button in the lobby.
        if (!isHost) {
          ref.read(roomControllerProvider.notifier).leaveRoom();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const PText('لابی'),
          leading: const AppBackButton(),
        ),
        body: LetteredBackdrop(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RoomCodeCard(code: roomCode),
                  const SizedBox(height: AppSpacing.xl),
                  PText(
                    'بازیکنان (${(room?.players.length ?? 0).toPersianString()})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: room == null
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.separated(
                            itemCount: room.players.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) {
                              final player = room.players[index];
                              final tile = _PlayerTile(
                                player: player,
                                showNpcBadge: room.isSoloGame,
                              );
                              // The host's own tile is already on screen when
                              // the lobby first renders — only newly-joining
                              // players (their tile appearing at a higher
                              // index later) get the join-in animation.
                              return tile
                                  .animate(key: ValueKey(player.id))
                                  .fadeIn(
                                    duration: 350.ms,
                                    curve: Curves.easeOut,
                                  )
                                  .slideY(
                                    begin: 0.4,
                                    end: 0,
                                    duration: 350.ms,
                                    curve: Curves.easeOutBack,
                                  )
                                  .scaleXY(
                                    begin: 0.85,
                                    end: 1,
                                    duration: 350.ms,
                                    curve: Curves.easeOutBack,
                                  );
                            },
                          ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (isOnlineGame)
                    const _FillingLobbyIndicator()
                  else if (isHost) ...[
                    GradientButton(
                      label: canStart
                          ? 'شروع بازی'
                          : 'در انتظار بازیکن بیشتر...',
                      onTap: canStart
                          ? () => ref
                                .read(roomControllerProvider.notifier)
                                .startGame()
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    GradientButton(
                      label: 'حذف اتاق',
                      gradient: LinearGradient(
                        colors: [
                          gameTheme.invalidColor,
                          gameTheme.invalidColor,
                        ],
                      ),
                      onTap: () => _confirmDeleteRoom(context, ref),
                    ),
                  ] else
                    Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: PText(
                            'منتظر شروع بازی توسط میزبان...',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .fadeIn(duration: 900.ms)
                        .then()
                        .fade(begin: 1, end: 0.6, duration: 900.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteRoom(BuildContext context, WidgetRef ref) async {
    ref.read(soundServiceProvider).playButtonClick();
    final ok = await ConfirmDialog.show(
      context,
      title: 'حذف اتاق؟',
      message: 'اتاق برای همه بسته می‌شود و بازیکنان خارج می‌شوند.',
      confirmLabel: 'حذف اتاق',
    );
    if (ok != true || !context.mounted) return;
    ref.read(roomControllerProvider.notifier).leaveRoom();
    if (context.canPop()) context.pop();
  }
}

/// Shown in "بازی آنلاین" lobbies while opponents are still joining — the
/// player never presses anything here, the server fills the lobby and
/// starts automatically, so this is purely a lively "hang tight" moment
/// with three bouncing dots rather than a static waiting message.
class _FillingLobbyIndicator extends StatelessWidget {
  const _FillingLobbyIndicator();

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child:
                      Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: gameTheme.heroGradient.colors.first,
                              shape: BoxShape.circle,
                            ),
                          )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scaleXY(
                            begin: 0.6,
                            end: 1.3,
                            duration: 500.ms,
                            delay: (i * 150).ms,
                            curve: Curves.easeInOut,
                          )
                          .fade(
                            begin: 0.5,
                            end: 1,
                            duration: 500.ms,
                            delay: (i * 150).ms,
                          ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PText(
            'در حال پیدا کردن بازیکنان...',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _RoomCodeCard extends ConsumerWidget {
  const _RoomCodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameTheme = context.gameTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: gameTheme.heroGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          const PText('کد اتاق', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: AppSpacing.xs),
          PText(
            code,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
            ),
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              _ActionChip(
                icon: LucideIcons.copy,
                label: 'کپی',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: PText('کد کپی شد')));
                },
              ),
              _ActionChip(
                icon: LucideIcons.share2,
                label: 'اشتراک‌گذاری',
                onTap: () {
                  SharePlaceholder.share(
                    'به اتاق من در اسم و فامیل یار بپیوند! کد: $code',
                  );
                },
              ),
              _ActionChip(
                icon: LucideIcons.messageCircle,
                label: 'دعوت در چت',
                onTap: () {
                  ref
                      .read(chatControllerProvider.notifier)
                      .send('حریف می‌طلبم! کد اتاق: $code');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: PText('دعوت در چت عمومی ارسال شد')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends ConsumerWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: () {
          ref.read(soundServiceProvider).playButtonClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: AppSpacing.xs),
              PText(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.player, required this.showNpcBadge});

  final Player player;

  /// Only true in "بازی سریع" rooms. The server already masks `isNpc` to
  /// false for "بازی آنلاین" disguised opponents, but gating on this too
  /// keeps the badge from ever appearing there even if that changes.
  final bool showNpcBadge;

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          PlayerAvatar(name: player.name, avatarUrl: player.avatarUrl),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: ColoredName(
                    player.name,
                    colorHex: player.nameColorHex,
                    style: Theme.of(context).textTheme.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (showNpcBadge && player.isNpc) ...[
                  const SizedBox(width: AppSpacing.xs),
                  const NpcBadge(),
                ],
              ],
            ),
          ),
          if (player.isHost)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: gameTheme.goldColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: PText(
                'میزبان',
                style: TextStyle(color: gameTheme.goldColor, fontSize: 12),
              ),
            ),
          if (!player.connected) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(LucideIcons.wifiOff, size: 16, color: gameTheme.invalidColor),
          ],
        ],
      ),
    );
  }
}

/// Placeholder for native share sheet integration — swapped for
/// share_plus (or similar) when the Final Scoreboard "share result" phase
/// is built, so both share entry points reuse the same plumbing.
class SharePlaceholder {
  static void share(String text) {
    // Intentionally a no-op stub for now; copy-to-clipboard above already
    // covers the practical "send code to a friend" need until real share
    // sheet integration is wired up.
  }
}
