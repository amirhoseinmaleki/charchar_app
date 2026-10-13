import 'package:flutter/material.dart';

/// Wraps the app in RTL text direction. The entire UI is Persian-only, so
/// this is applied once at the root rather than per-screen.
class ForceRtl extends StatelessWidget {
  const ForceRtl({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: child);
  }
}
