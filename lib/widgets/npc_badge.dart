import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import './p_text.dart';

/// Small "بازیکن مجازی" tag shown next to any NPC's name — the spec
/// requires NPC opponents to be clearly and honestly labeled everywhere
/// they appear, never presented as real people.
class NpcBadge extends StatelessWidget {
  const NpcBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: PText('بازیکن مجازی', style: TextStyle(color: color, fontSize: 11)),
    );
  }
}
