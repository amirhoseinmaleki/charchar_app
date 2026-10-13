import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth.dart';
import '../models/game_history.dart';
import '../providers/auth_provider.dart';
import '../providers/game_history_provider.dart';
import '../providers/leaderboard_provider.dart';
import '../providers/remote_config_provider.dart';
import '../providers/shop_provider.dart';
import '../models/leaderboard.dart';
import '../models/shop.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/name_color.dart';
import '../utils/persian_numbers.dart';
import '../widgets/app_back_button.dart';
import '../widgets/error_dialog.dart';
import '../widgets/floating_letters_background.dart';
import '../widgets/gradient_button.dart';
import '../widgets/player_avatar.dart';
import '../widgets/player_identity_header.dart';
import '../widgets/p_text.dart';

/// Profile view: avatar, editable nickname, coin balance, and lifetime
/// rank/score pulled from the same leaderboard endpoint the Leaderboard
/// screen uses (`myRank`) rather than a separate "whoami stats" endpoint
/// that doesn't exist yet on the backend.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _nicknameController;
  bool _isSavingNickname = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(
      text: ref.read(authControllerProvider).player?.nickname ?? '',
    );
    // Pull the catalog so the "ظاهر من" section knows which cosmetics are
    // owned / equipped. Safe to call even if the Shop screen already loaded.
    Future.microtask(() => ref.read(shopControllerProvider.notifier).load());
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  bool get _isValidNickname {
    final text = _nicknameController.text.trim();
    return text.length >= 2 && text.length <= 20;
  }

  Future<void> _saveNickname() async {
    if (!_isValidNickname || _isSavingNickname) return;
    setState(() => _isSavingNickname = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .setNickname(_nicknameController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: PText('نام مستعار ذخیره شد')));
      }
    } on AuthException catch (e) {
      if (mounted) ErrorDialog.show(context, e.message);
    } catch (_) {
      if (mounted) ErrorDialog.show(context, 'ارتباط با سرور برقرار نشد.');
    } finally {
      if (mounted) setState(() => _isSavingNickname = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;
    final rankAsync = ref.watch(leaderboardProvider(LeaderboardScope.allTime));
    final recentGamesAsync = ref.watch(recentGamesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const PText('پروفایل'),
        leading: const AppBackButton(),
      ),
      body: LetteredBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.lg),
                // Same identity block as Home. Isolated so equipping a
                // cosmetic (which updates auth.player) rebuilds just this,
                // not the whole scroll view.
                Consumer(
                  builder: (context, ref, _) {
                    final player = ref.watch(authControllerProvider).player;
                    final score = (player?.totalScore != null && player!.totalScore > 0)
                        ? player.totalScore
                        : rankAsync.valueOrNull?.myRank?.score;
                    final leveling = ref.watch(remoteConfigValueProvider
                        .select((c) => c.config.leveling));
                    final level = (player?.level != null && player!.level > 1)
                        ? player.level
                        : (score != null && score > 0
                            ? leveling.levelForScore(score)
                            : (player?.level ?? 1));
                    return PlayerIdentityHeader(
                      nickname: player?.nickname,
                      avatarUrl: player?.avatarUrl,
                      nameColorHex: player?.nameColorHex,
                      level: level,
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                const _AppearanceSection(),
                const SizedBox(height: AppSpacing.xxl),
                _NicknameEditor(
                  controller: _nicknameController,
                  isSaving: _isSavingNickname,
                  isValid: _isValidNickname,
                  onSave: _saveNickname,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.xl),
                rankAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (_, _) => PText(
                    'آماری موجود نیست',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  data: (result) {
                    final myRank = result.myRank;
                    return Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'امتیاز کل',
                            value: (myRank?.score ?? 0).toPersianStringGrouped(),
                            color: gameTheme.goldColor,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _StatCard(
                            label: 'رتبه (همه زمان‌ها)',
                            value: myRank != null
                                ? '#${myRank.rank.toPersianString()}'
                                : '—',
                            color: gameTheme.successColor,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: Alignment.centerRight,
                  child: PText(
                    'بازی‌های اخیر',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                recentGamesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => PText(
                    'بازی‌های اخیر قابل نمایش نیست',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  data: (games) {
                    if (games.isEmpty) {
                      return PText(
                        'هنوز بازی‌ای انجام نداده‌اید',
                        style: Theme.of(context).textTheme.bodyMedium,
                      );
                    }
                    return Column(
                      children: [
                        for (final game in games) _GameHistoryRow(entry: game),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "ظاهر من" — equip an owned avatar and/or name-color. Reads owned/equipped
/// state from the shop catalog; tapping calls the equip endpoint, which
/// updates the player's appearance app-wide.
/// The nickname field + save button, plus a line explaining the change
/// policy (first set free, one paid change, then locked). Isolated in a
/// [Consumer] so it reacts to `auth.player` (changes-remaining, balance)
/// without rebuilding the whole profile.
class _NicknameEditor extends ConsumerWidget {
  const _NicknameEditor({
    required this.controller,
    required this.isSaving,
    required this.isValid,
    required this.onSave,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool isSaving;
  final bool isValid;
  final VoidCallback onSave;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(authControllerProvider.select((s) => s.player));
    final hasName = (player?.nickname ?? '').isNotEmpty;
    final remaining = player?.nicknameChangesRemaining ?? 0;
    final cost = player?.nicknameChangeCost ?? 0;
    final locked = hasName && remaining <= 0;

    // A change (not the first set) costs coins.
    final changeWouldCost = hasName && remaining > 0 ? cost : 0;
    final canAfford = (player?.coinBalance ?? 0) >= changeWouldCost;

    final gameTheme = context.gameTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: PText(
            'نام مستعار',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          maxLength: 20,
          enabled: !locked,
          buildCounter: persianCounter,
          decoration: const InputDecoration(hintText: 'نام مستعار'),
          onChanged: (_) => onChanged(),
        ),
        if (locked) ...[
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: PText(
              'شما دیگر نمی‌توانید نام مستعار خود را تغییر دهید.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: gameTheme.invalidColor),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        GradientButton(
          label: changeWouldCost > 0
              ? 'تغییر نام (${cost.toPersianString()} سکه)'
              : 'ذخیره نام',
          isLoading: isSaving,
          onTap: (!locked && isValid && canAfford) ? onSave : null,
        ),
        if (changeWouldCost > 0 && !canAfford) ...[
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: PText(
              'سکه کافی برای تغییر نام ندارید.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: gameTheme.invalidColor),
            ),
          ),
        ],
      ],
    );
  }
}

class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(shopControllerProvider);
    final catalog = shop.catalog;
    if (catalog == null) return const SizedBox.shrink();

    final ownedAvatars = catalog.items
        .where((i) => i.category == ShopCategory.avatar && i.owned)
        .toList();
    final ownedColors = catalog.items
        .where((i) => i.category == ShopCategory.nameColor && i.owned)
        .toList();

    if (ownedAvatars.isEmpty && ownedColors.isEmpty) {
      return Align(
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PText(
              'ظاهر من',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: AppSpacing.sm),
            PText(
              'هنوز آواتار یا رنگ اسمی نخریده‌اید. از فروشگاه تهیه کنید.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.right,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: PText(
            'ظاهر من',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (ownedAvatars.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: PText(
              'آواتار',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _AvatarOption(
                key: const ValueKey('avatar_default'),
                label: 'پیش‌فرض',
                avatarUrl: null,
                selected: catalog.equippedAvatarId == null,
                busy: shop.equippingItemId == '__none_avatar',
                onTap: () => ref
                    .read(shopControllerProvider.notifier)
                    .equip(ShopCategory.avatar, null),
              ),
              for (final item in ownedAvatars)
                _AvatarOption(
                  key: ValueKey('avatar_${item.id}'),
                  label: item.labelFa,
                  avatarUrl: '/assets/avatar/${item.id}.png',
                  selected: catalog.equippedAvatarId == item.id,
                  busy: shop.equippingItemId == item.id,
                  onTap: () => ref
                      .read(shopControllerProvider.notifier)
                      .equip(ShopCategory.avatar, item.id),
                ),
            ],
          ),
        ],
        if (ownedColors.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: PText(
              'رنگ اسم',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _ColorSwatch(
                key: const ValueKey('color_default'),
                label: 'پیش‌فرض',
                color: Theme.of(context).textTheme.bodyLarge?.color,
                selected: catalog.equippedNameColorId == null,
                busy: shop.equippingItemId == '__none_nameColor',
                onTap: () => ref
                    .read(shopControllerProvider.notifier)
                    .equip(ShopCategory.nameColor, null),
              ),
              for (final item in ownedColors)
                _ColorSwatch(
                  key: ValueKey('color_${item.id}'),
                  label: item.labelFa,
                  color: parseNameColor(item.hex),
                  selected: catalog.equippedNameColorId == item.id,
                  busy: shop.equippingItemId == item.id,
                  onTap: () => ref
                      .read(shopControllerProvider.notifier)
                      .equip(ShopCategory.nameColor, item.id),
                ),
            ],
          ),
        ],
        if (shop.error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          PText(
            shop.error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

class _AvatarOption extends StatelessWidget {
  const _AvatarOption({
    super.key,
    required this.label,
    required this.avatarUrl,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final String? avatarUrl;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: busy ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? gameTheme.heroGradient.colors.first
                    : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: busy
                ? const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : PlayerAvatar(name: label, avatarUrl: avatarUrl, radius: 26),
          ),
          const SizedBox(height: AppSpacing.xs),
          PText(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: selected ? Colors.white : Colors.white70,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final Color? color;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected
                ? gameTheme.heroGradient.colors.first
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color ?? Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
              ),
            const SizedBox(width: AppSpacing.xs),
            PText(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.check, size: 16, color: gameTheme.successColor),
            ],
          ],
        ),
      ),
    );
  }
}

class _GameHistoryRow extends StatelessWidget {
  const _GameHistoryRow({required this.entry});

  final GameHistoryEntry entry;

  IconData get _modeIcon => switch (entry.mode) {
    GameMode.solo => Icons.smart_toy_outlined,
    GameMode.online => Icons.bolt_outlined,
    GameMode.multiplayer => Icons.people_outline,
  };

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;
    final isFinished = entry.isFinished;
    final coinsEarned = entry.coinsEarned ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(_modeIcon, size: 20, color: gameTheme.heroGradient.colors.first),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: PText(
              entry.mode.labelFa,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (isFinished)
            Wrap(
              spacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PText(
                  '${entry.score!.toPersianStringGrouped()} امتیاز',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: gameTheme.goldColor),
                ),
                if (coinsEarned > 0)
                  PText(
                    '+${coinsEarned.toPersianString()} سکه',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: gameTheme.goldColor,
                    ),
                  ),
                PText(
                  '#${entry.rank!.toPersianString()}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: gameTheme.successColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          else
            PText(
              'ناتمام',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: gameTheme.invalidColor),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          PText(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: color),
          ),
          const SizedBox(height: AppSpacing.xs),
          PText(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
