import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/socket_provider.dart';
import '../services/socket_service.dart';
import '../theme/app_spacing.dart';
import './p_text.dart';

/// Shows connection state at all times — never a silent hang. This is the
/// #1 complaint pattern called out in the spec for competing apps.
class ConnectionStatusBar extends ConsumerWidget {
  const ConnectionStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(connectionStatusProvider);
    final status = statusAsync.valueOrNull ?? ConnectionStatus.connecting;

    if (status == ConnectionStatus.connected) return const SizedBox.shrink();

    final (label, color) = switch (status) {
      ConnectionStatus.connecting => ('در حال اتصال به سرور...', Colors.amber),
      ConnectionStatus.reconnecting => ('در حال اتصال مجدد...', Colors.amber),
      ConnectionStatus.disconnected => ('اتصال به سرور قطع شد', Theme.of(context).colorScheme.error),
      ConnectionStatus.unauthorized => ('نشست شما منقضی شده است', Theme.of(context).colorScheme.error),
      ConnectionStatus.connected => ('', Colors.transparent),
    };

    final isErrorState = status == ConnectionStatus.disconnected || status == ConnectionStatus.unauthorized;

    return Material(
      color: color.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: isErrorState
                  ? Icon(Icons.error_outline, size: 14, color: color)
                  : CircularProgressIndicator(strokeWidth: 2, color: color),
            ),
            const SizedBox(width: AppSpacing.sm),
            PText(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
