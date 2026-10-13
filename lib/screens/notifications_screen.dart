import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification.dart';
import '../providers/notification_provider.dart';
import '../providers/sound_provider.dart';
import '../theme/app_images.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/persian_numbers.dart';
import '../widgets/app_back_button.dart';
import '../widgets/floating_letters_background.dart';
import '../widgets/p_text.dart';

/// In-app broadcast notifications: a newest-first list with per-item read
/// state, keyset paging, tap-to-mark-read, and a "همه را خواندم" action.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(notificationsControllerProvider.notifier).load());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      ref.read(notificationsControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsControllerProvider);
    final controller = ref.read(notificationsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const PText('اعلان‌ها'),
        leading: const AppBackButton(),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () {
                ref.read(soundServiceProvider).playButtonClick();
                controller.markAllRead();
              },
              child: const PText('همه را خواندم'),
            ),
        ],
      ),
      body: LetteredBackdrop(
        child: SafeArea(
          child: _body(context, state, controller),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, NotificationsState state, NotificationsController controller) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return _CenteredMessage(
        icon: Icons.wifi_off_rounded,
        title: 'اعلان‌ها بارگذاری نشد',
        subtitle: 'اتصالت را بررسی کن و دوباره تلاش کن.',
        action: TextButton(onPressed: controller.load, child: const PText('تلاش دوباره')),
      );
    }
    if (state.items.isEmpty) {
      return const _CenteredMessage(
        iconImage: AppImages.notification,
        title: 'فعلاً اعلانی نداری',
        subtitle: 'خبرها و جایزه‌ها اینجا نشان داده می‌شوند.',
      );
    }

    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, i) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          if (index >= state.items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final n = state.items[index];
          return _NotificationCard(
            notification: n,
            onTap: () {
              ref.read(soundServiceProvider).playButtonClick();
              controller.markRead(n.id);
            },
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;
    final accent = gameTheme.heroGradient.colors.first;
    final unread = !notification.read;

    return GestureDetector(
      onTap: unread ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color?.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: unread ? Border.all(color: accent.withValues(alpha: 0.6), width: 1.5) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unread dot.
            Container(
              margin: const EdgeInsets.only(top: 6),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: unread ? accent : Colors.transparent,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PText(
                    notification.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  PText(
                    notification.body,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  PText(
                    _relativeTime(notification.createdAtLocal),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF9AA0A6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _relativeTime(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'همین الان';
  if (d.inMinutes < 60) return '${d.inMinutes.toPersianString()} دقیقه پیش';
  if (d.inHours < 24) return '${d.inHours.toPersianString()} ساعت پیش';
  if (d.inDays < 30) return '${d.inDays.toPersianString()} روز پیش';
  return '${(d.inDays ~/ 30).toPersianString()} ماه پیش';
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    this.icon,
    this.iconImage,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData? icon;
  final String? iconImage;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconImage != null)
              Image.asset(iconImage!, width: 64, height: 64)
            else if (icon != null)
              Icon(icon, size: 56, color: context.gameTheme.heroGradient.colors.first),
            const SizedBox(height: AppSpacing.lg),
            PText(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            PText(subtitle, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: AppSpacing.lg), action!],
          ],
        ),
      ),
    );
  }
}
